#define C_KINO_SIMILARITY
#include "KinoSearch/Util/ToolSet.h"

#include "math.h"

#include "KinoSearch/Index/Similarity.h"

#include "KinoSearch/Index/Posting/ScorePosting.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Posting/MatchPosting.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

Similarity*
Sim_new()
{
    Similarity *self = (Similarity*)VTable_Make_Obj(SIMILARITY);
    return Sim_init(self);
}

Similarity*
Sim_init(Similarity *self) 
{
    self->norm_decoder = NULL;
    return self;
}

void
Sim_destroy(Similarity *self) 
{
    if (self->norm_decoder) {
        FREEMEM(self->norm_decoder);
    }
    SUPER_DESTROY(self, SIMILARITY);
}

Posting*
Sim_make_posting(Similarity *self)
{
    return (Posting*)ScorePost_new(self);
}

PostingWriter*
Sim_make_posting_writer(Similarity *self, Schema *schema, Snapshot *snapshot,
                        Segment *segment, PolyReader *polyreader,
                        int32_t field_num)
{
    UNUSED_VAR(self);
    return (PostingWriter*)MatchPostWriter_new(schema, snapshot, segment, 
        polyreader, field_num);
}

float*
Sim_get_norm_decoder(Similarity *self)
{ 
    if (!self->norm_decoder) {
        // Cache decoded boost bytes. 
        self->norm_decoder = (float*)MALLOCATE(256 * sizeof(float));
        for (uint32_t i = 0; i < 256; i++) {
            self->norm_decoder[i] = Sim_Decode_Norm(self, i);
        }
    }
    return self->norm_decoder; 
}

Obj*
Sim_dump(Similarity *self)
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(Sim_Get_Class_Name(self)));
    return (Obj*)dump;
}

Similarity*
Sim_load(Similarity *self, Obj *dump)
{
    Hash *source = (Hash*)CERTIFY(dump, HASH);
    CharBuf *class_name = (CharBuf*)CERTIFY(
        Hash_Fetch_Str(source, "_class", 6), CHARBUF);
    VTable *vtable = VTable_singleton(class_name, NULL);
    Similarity *loaded = (Similarity*)VTable_Make_Obj(vtable);
    UNUSED_VAR(self);
    return Sim_init(loaded);
}

void
Sim_serialize(Similarity *self, OutStream *target)
{
    // Only the class name. 
    CB_Serialize(Sim_Get_Class_Name(self), target);
}

Similarity*
Sim_deserialize(Similarity *self, InStream *instream)
{
    CharBuf *class_name = CB_deserialize(NULL, instream);
    if (!self) {
        VTable *vtable = VTable_singleton(class_name, SIMILARITY);
        self = (Similarity*)VTable_Make_Obj(vtable);
    }
    else if (!CB_Equals(class_name, (Obj*)Sim_Get_Class_Name(self))) {
        THROW(ERR, "Class name mismatch: '%o' '%o'", Sim_Get_Class_Name(self),
            class_name);
    }
    DECREF(class_name);

    Sim_init(self);
    return self;
}

bool_t
Sim_equals(Similarity *self, Obj *other)
{
    if (Sim_Get_VTable(self) != Obj_Get_VTable(other)) return false;
    return true;
}

float
Sim_idf(Similarity *self, int64_t doc_freq, int64_t total_docs)
{
    UNUSED_VAR(self);
    if (total_docs == 0) {
        // Guard against log of zero error, return meaningless number. 
        return 1;
    }
    else {
        double total_documents = (double)total_docs;
        double document_freq   = (double)doc_freq;
        return (float)(1 + log( total_documents / (1 + document_freq) ));
    }
}

float
Sim_tf(Similarity *self, float freq) 
{
    UNUSED_VAR(self);
    return (float)sqrt(freq);
}

uint32_t
Sim_encode_norm(Similarity *self, float f) 
{
    uint32_t norm;
    UNUSED_VAR(self);

    if (f < 0.0)
        f = 0.0;

    if (f == 0.0) {
        norm = 0;
    }
    else {
        const uint32_t bits = *(uint32_t*)&f;
        uint32_t mantissa   = (bits & 0xffffff) >> 21;
        uint32_t exponent   = (((bits >> 24) & 0x7f)-63) + 15;

        if (exponent > 31) {
            exponent = 31;
            mantissa = 7;
        }
         
        norm = (exponent << 3) | mantissa;
    }

    return norm;
}

float
Sim_decode_norm(Similarity *self, uint32_t input) 
{
    uint8_t  byte = input & 0xFF;
    uint32_t result;
    UNUSED_VAR(self);

    if (byte == 0) {
        result = 0;
    }
    else {
        const uint32_t mantissa = byte & 7;
        const uint32_t exponent = (byte >> 3) & 31;
        result = ((exponent+(63-15)) << 24) | (mantissa << 21);
    }
    
    return *(float*)&result;
}

float 
Sim_length_norm(Similarity *self, uint32_t num_tokens)
{
    UNUSED_VAR(self);
    if (num_tokens == 0) // guard against div by zero 
        return 0;
    else
        return (float)( 1.0 / sqrt((double)num_tokens) );
}

float
Sim_query_norm(Similarity *self, float sum_of_squared_weights)
{
    UNUSED_VAR(self);
    if (sum_of_squared_weights == 0.0f) // guard against div by zero 
        return 0;
    else
        return (float)( 1.0 / sqrt(sum_of_squared_weights) );
}

float
Sim_coord(Similarity *self, uint32_t overlap, uint32_t max_overlap) 
{
    UNUSED_VAR(self);
    if (max_overlap == 0)
        return 1;
    else 
        return (float)overlap / (float)max_overlap;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

