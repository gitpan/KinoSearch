#include "KinoSearch/Util/ToolSet.h"

#include "math.h"

#define KINO_WANT_SIMILARITY_VTABLE
#include "KinoSearch/Search/Similarity.r"


Similarity*
Sim_new(const char *class_name) 
{
    u32_t i;
    CREATE_SUBCLASS(self, class_name, Similarity, SIMILARITY);

    /* cache decoded norms and proximity boost factors */
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
    free(self);
}

void
Sim_serialize(Similarity *self, ByteBuf *target)
{
    const u32_t class_name_len = strlen(self->_->class_name);
    const u32_t new_len = target->len + sizeof(u32_t) + class_name_len;
    char *ptr;

    /* make room */
    BB_GROW(target, new_len);
    ptr = BBEND(target);
    target->len = new_len;

    /* only the class name */
    MATH_ENCODE_U32(class_name_len, ptr);
    ptr += sizeof(u32_t);
    memcpy(ptr, (char*)self->_->class_name, class_name_len);
}

Similarity*
Sim_deserialize(ViewByteBuf *serialized)
{
    u32_t class_name_len;
    ByteBuf *class_name;
    Similarity *self;

    /* extract class name, sanity checking as we go */
    if (serialized->len < sizeof(u32_t))
        CONFESS("Not enough bytes: %u", serialized->len);
    MATH_DECODE_U32(class_name_len, serialized->ptr);
    serialized->len -= sizeof(u32_t);
    serialized->ptr += sizeof(u32_t);
    if (serialized->len < class_name_len)
        CONFESS("Not enough bytes: %u %u", class_name_len, serialized->len);
    class_name = BB_new_str(serialized->ptr, class_name_len);
    serialized->len -= class_name_len;
    serialized->ptr += class_name_len;

    /* just create a new object */
    self = Sim_new(class_name->ptr);
    REFCOUNT_DEC(class_name);
    
    return self;
}

float
Sim_tf(Similarity *self, float freq) 
{
    UNUSED_VAR(self);
    return( sqrt(freq) );
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
Sim_query_norm(Similarity *self, float sum_of_squared_weights)
{
    if (sum_of_squared_weights == 0.0f) /* guard against div by zero */
        return 0;
    else
        return ( 1.0f / sqrt(sum_of_squared_weights) );
}

float
Sim_prox_boost(Similarity *self, u32_t distance)
{
    UNUSED_VAR(self);
    if (distance == 0)
        return 0;
    else 
        return 1.0/(float)distance;

}

float
Sim_prox_coord(Similarity *self, u32_t *prox, u32_t num_prox)
{
    float *prox_decoder = self->prox_decoder;
    u32_t *a = prox;
    u32_t *const limit = prox + num_prox;
    float bonus = 0;

    /* add to bonus for each pair of positions within 256 tokens */
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
     return 1.0 + bonus/num_prox;
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

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

