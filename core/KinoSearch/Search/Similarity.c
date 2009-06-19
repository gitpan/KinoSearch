#include "KinoSearch/Util/ToolSet.h"

#include "math.h"

#include "KinoSearch/Search/Similarity.h"

#include "KinoSearch/Search/Searchable.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

Similarity*
Sim_new()
{
    Similarity *self = (Similarity*)VTable_Make_Obj(&SIMILARITY);
    return Sim_init(self);
}

Similarity*
Sim_init(Similarity *self) 
{
    u32_t i;

    /* Cache decoded norms and proximity boost factors. */
    self->norm_decoder = MALLOCATE(256, float);
    self->prox_decoder = MALLOCATE(256, float);
    for (i = 0; i < 256; i++) {
        self->norm_decoder[i] = Sim_Decode_Norm(self, i);
        self->prox_decoder[i] = Sim_Prox_Boost(self, i);
    }

    return self;
}

void
Sim_destroy(Similarity *self) 
{
    free(self->norm_decoder);
    free(self->prox_decoder);
    FREE_OBJ(self);
}

Obj*
Sim_dump(Similarity *self)
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(Obj_Get_Class_Name(self)));
    return (Obj*)dump;
}

Similarity*
Sim_load(Similarity *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *class_name = (CharBuf*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "_class", 6), CHARBUF);
    VTable *vtable = VTable_singleton(class_name, NULL);
    Similarity *loaded = (Similarity*)VTable_Make_Obj(vtable);
    UNUSED_VAR(self);
    return Sim_init(loaded);
}

void
Sim_serialize(Similarity *self, OutStream *target)
{
    /* Only the class name. */
    CB_Serialize(Obj_Get_Class_Name(self), target);
}

Similarity*
Sim_deserialize(Similarity *self, InStream *instream)
{
    CharBuf *class_name = CB_deserialize(NULL, instream);
    if (!self) {
        VTable *vtable = VTable_singleton(class_name, (VTable*)&SIMILARITY);
        self = (Similarity*)VTable_Make_Obj(vtable);
    }
    else if (!CB_Equals(class_name, (Obj*)Obj_Get_Class_Name(self))) {
        THROW("Class name mismatch: '%o' '%o'", Obj_Get_Class_Name(self),
            class_name);
    }
    DECREF(class_name);

    Sim_init(self);
    return self;
}

bool_t
Sim_equals(Similarity *self, Obj *other)
{
    if (Obj_Get_VTable(self) != Obj_Get_VTable(other)) return false;
    return true;
}

float
Sim_idf(Similarity *self, Searchable *searchable, const CharBuf *field, 
        Obj *term)
{
    double doc_max = Searchable_Doc_Max(searchable);
    UNUSED_VAR(self);
    
    if (doc_max == 0) {
        /* Guard against log of zero error, return meaningless number. */
        return 1;
    }
    else {
        double doc_freq = Searchable_Doc_Freq(searchable, field, term);
        return (float)(1 + log( doc_max / (1 + doc_freq) ));
    }
}

float
Sim_tf(Similarity *self, float freq) 
{
    UNUSED_VAR(self);
    return (float)sqrt(freq);
}

u32_t
Sim_encode_norm(Similarity *self, float f) 
{
    u32_t norm;
    UNUSED_VAR(self);

    if (f < 0.0)
        f = 0.0;

    if (f == 0.0) {
        norm = 0;
    }
    else {
        const u32_t bits = *(u32_t*)&f;
        u32_t mantissa   = (bits & 0xffffff) >> 21;
        u32_t exponent   = (((bits >> 24) & 0x7f)-63) + 15;

        if (exponent > 31) {
            exponent = 31;
            mantissa = 7;
        }
         
        norm = (exponent << 3) | mantissa;
    }

    return norm;
}

float
Sim_decode_norm(Similarity *self, u32_t input) 
{
    u8_t byte = input & 0xFF;
    u32_t result;
    UNUSED_VAR(self);

    if (byte == 0) {
        result = 0;
    }
    else {
        const u32_t mantissa = byte & 7;
        const u32_t exponent = (byte >> 3) & 31;
        result = ((exponent+(63-15)) << 24) | (mantissa << 21);
    }
    
    return *(float*)&result;
}

float 
Sim_length_norm(Similarity *self, u32_t num_tokens)
{
    UNUSED_VAR(self);
    if (num_tokens == 0) /* guard against div by zero */
        return 0;
    else
        return (float)( 1.0 / sqrt(num_tokens) );
}

float
Sim_query_norm(Similarity *self, float sum_of_squared_weights)
{
    UNUSED_VAR(self);
    if (sum_of_squared_weights == 0.0f) /* guard against div by zero */
        return 0;
    else
        return (float)( 1.0 / sqrt(sum_of_squared_weights) );
}

float
Sim_prox_boost(Similarity *self, u32_t distance)
{
    UNUSED_VAR(self);
    if (distance == 0)
        return 0.0f;
    else 
        return 1.0f/(float)distance;

}

float
Sim_prox_coord(Similarity *self, u32_t *prox, u32_t num_prox)
{
    float *prox_decoder = self->prox_decoder;
    u32_t *a = prox;
    u32_t *const limit = prox + num_prox;
    float bonus = 0;

    /* Add to bonus for each pair of positions within 256 tokens. */
    for ( ; a < limit - 1; a++) {
        u32_t *b = a + 1;
        u32_t distance = *b - *a;
        for ( ; distance < 256 && b < limit; b++) {
            bonus += prox_decoder[distance];
            distance = *b - *a;
        }
    }

    /* Damp the scoring multiplier.  Ideally, we would want to know the number
     * of tokens in the field, but we don't have the token count available so
     * that's not a possibility.  Fortunately, using the number of positions
     * matched works OK because it's likely to be roughly proportionate to
     * field length.
     */
     return 1.0f + bonus/num_prox;
}

float
Sim_coord(Similarity *self, u32_t overlap, u32_t max_overlap) 
{
    UNUSED_VAR(self);
    if (max_overlap == 0)
        return 1;
    else 
        return (float)overlap / (float)max_overlap;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

