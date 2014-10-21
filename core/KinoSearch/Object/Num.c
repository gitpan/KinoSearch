#define C_KINO_NUM
#define C_KINO_INTNUM
#define C_KINO_FLOATNUM
#define C_KINO_INTEGER32
#define C_KINO_INTEGER64
#define C_KINO_FLOAT32
#define C_KINO_FLOAT64
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Object/Num.h"
#include "KinoSearch/Object/CharBuf.h"
#include "KinoSearch/Object/Err.h"
#include "KinoSearch/Object/VTable.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

Num*
Num_init(Num *self)
{
    ABSTRACT_CLASS_CHECK(self, NUM);
    return self;
}

bool_t
Num_equals(Num *self, Obj *other)
{
    Num *evil_twin = (Num*)other;
    if (evil_twin == self) { return true; }
    if (!Obj_Is_A(other, NUM)) { return false; }
    if (Num_To_F64(self) != Num_To_F64(evil_twin)) { return false; }
    if (Num_To_I64(self) != Num_To_I64(evil_twin)) { return false; }
    return true;
}

int32_t
Num_compare_to(Num *self, Obj *other)
{
    Num *evil_twin = (Num*)CERTIFY(other, NUM);
    double f64_diff = Num_To_F64(self) - Num_To_F64(evil_twin);
    if (f64_diff) {
        if      (f64_diff < 0) { return -1; }
        else if (f64_diff > 0) { return 1;  }
    }
    else {
        int64_t i64_diff = Num_To_I64(self) - Num_To_I64(evil_twin);
        if (i64_diff) { 
            if      (i64_diff < 0) { return -1; }
            else if (i64_diff > 0) { return 1;  }
        }
    }
    return 0;
}

/***************************************************************************/

FloatNum*
FloatNum_init(FloatNum *self)
{
    ABSTRACT_CLASS_CHECK(self, FLOATNUM);
    return (FloatNum*)Num_init((Num*)self);
}

CharBuf*
FloatNum_to_string(FloatNum *self)
{
    return CB_newf("%f64", FloatNum_To_F64(self));
}

/***************************************************************************/

IntNum*
IntNum_init(IntNum *self)
{
    ABSTRACT_CLASS_CHECK(self, INTNUM);
    return (IntNum*)Num_init((Num*)self);
}

CharBuf*
IntNum_to_string(IntNum *self)
{
    return CB_newf("%i64", IntNum_To_I64(self));
}

/***************************************************************************/

Float32*
Float32_new(float value)
{
    Float32 *self = (Float32*)VTable_Make_Obj(FLOAT32);
    return Float32_init(self, value);
}

Float32*
Float32_init(Float32 *self, float value)
{
    self->value = value;
    return (Float32*)FloatNum_init((FloatNum*)self);
}

float
Float32_get_value(Float32 *self) { return self->value; }
void
Float32_set_value(Float32 *self, float value) { self->value = value; }

double
Float32_to_f64(Float32 *self)
{
    return self->value;
}

int64_t
Float32_to_i64(Float32 *self)
{
    return (int64_t)self->value;
}

int32_t
Float32_hash_sum(Float32 *self)
{
    return *(int32_t*)&self->value;
}

Float32*
Float32_clone(Float32 *self)
{
    return Float32_new(self->value);
}

void
Float32_mimic(Float32 *self, Obj *other)
{
    Float32 *evil_twin = (Float32*)CERTIFY(other, FLOAT32);
    self->value = evil_twin->value;
}

void
Float32_serialize(Float32 *self, OutStream *outstream)
{
    OutStream_Write_F32(outstream, self->value);
}

Float32*
Float32_deserialize(Float32 *self, InStream *instream)
{
    float value = InStream_Read_F32(instream);
    return self ? Float32_init(self, value) : Float32_new(value);
}

/***************************************************************************/

Float64*
Float64_new(double value)
{
    Float64 *self = (Float64*)VTable_Make_Obj(FLOAT64);
    return Float64_init(self, value);
}

Float64*
Float64_init(Float64 *self, double value)
{
    self->value = value;
    return (Float64*)FloatNum_init((FloatNum*)self);
}

double
Float64_get_value(Float64 *self) { return self->value; }
void
Float64_set_value(Float64 *self, double value) { self->value = value; }

double
Float64_to_f64(Float64 *self)
{
    return self->value;
}

int64_t
Float64_to_i64(Float64 *self)
{
    return (int64_t)self->value;
}

Float64*
Float64_clone(Float64 *self)
{
    return Float64_new(self->value);
}

void
Float64_mimic(Float64 *self, Obj *other)
{
    Float64 *evil_twin = (Float64*)CERTIFY(other, FLOAT64);
    self->value = evil_twin->value;
}

int32_t
Float64_hash_sum(Float64 *self)
{
    int32_t *ints = (int32_t*)&self->value;
    return ints[0] ^ ints[1];
}

void
Float64_serialize(Float64 *self, OutStream *outstream)
{
    OutStream_Write_F64(outstream, self->value);
}

Float64*
Float64_deserialize(Float64 *self, InStream *instream)
{
    double value = InStream_Read_F64(instream);
    return self ? Float64_init(self, value) : Float64_new(value);
}

/***************************************************************************/

Integer32*
Int32_new(int32_t value)
{
    Integer32 *self = (Integer32*)VTable_Make_Obj(INTEGER32);
    return Int32_init(self, value);
}

Integer32*
Int32_init(Integer32 *self, int32_t value)
{
    self->value = value;
    return (Integer32*)IntNum_init((IntNum*)self);
}

int32_t
Int32_get_value(Integer32 *self) { return self->value; }
void
Int32_set_value(Integer32 *self, int32_t value) { self->value = value; }

double
Int32_to_f64(Integer32 *self)
{
    return self->value;
}

int64_t
Int32_to_i64(Integer32 *self)
{
    return self->value;
}

Integer32*
Int32_clone(Integer32 *self)
{
    return Int32_new(self->value);
}

void
Int32_mimic(Integer32 *self, Obj *other)
{
    Integer32 *evil_twin = (Integer32*)CERTIFY(other, INTEGER32);
    self->value = evil_twin->value;
}

int32_t
Int32_hash_sum(Integer32 *self)
{
    return self->value;
}

void
Int32_serialize(Integer32 *self, OutStream *outstream)
{
    OutStream_Write_C32(outstream, (uint32_t)self->value);
}

Integer32*
Int32_deserialize(Integer32 *self, InStream *instream)
{
    int32_t value = (int32_t)InStream_Read_C32(instream);
    return self ? Int32_init(self, value) : Int32_new(value);
}

/***************************************************************************/

Integer64*
Int64_new(int64_t value)
{
    Integer64 *self = (Integer64*)VTable_Make_Obj(INTEGER64);
    return Int64_init(self, value);
}

Integer64*
Int64_init(Integer64 *self, int64_t value)
{
    self->value = value;
    return (Integer64*)FloatNum_init((FloatNum*)self);
}

int64_t
Int64_get_value(Integer64 *self) { return self->value; }
void
Int64_set_value(Integer64 *self, int64_t value) { self->value = value; }

double
Int64_to_f64(Integer64 *self)
{
    return (double)self->value;
}

int64_t
Int64_to_i64(Integer64 *self)
{
    return self->value;
}

Integer64*
Int64_clone(Integer64 *self)
{
    return Int64_new(self->value);
}

void
Int64_mimic(Integer64 *self, Obj *other)
{
    Integer64 *evil_twin = (Integer64*)CERTIFY(other, INTEGER64);
    self->value = evil_twin->value;
}

int32_t
Int64_hash_sum(Integer64 *self)
{
    int32_t *ints = (int32_t*)&self->value;
    return ints[0] ^ ints[1];
}

bool_t
Int64_equals(Integer64 *self, Obj *other)
{
    Num *evil_twin = (Num*)other;
    if (evil_twin == (Num*)self)         { return true; }
    if (!Obj_Is_A(other, NUM)) { return false; }
    if (Num_Is_A(evil_twin, FLOATNUM)) {
        double  floating_val = Num_To_F64(evil_twin);
        int64_t int_val      = (int64_t)floating_val;
        if ((double)int_val != floating_val) { return false; }
        if (int_val != self->value)          { return false; }
    }
    else {
        if (self->value != Num_To_I64(evil_twin)) { return false; }
    }
    return true;
}

void
Int64_serialize(Integer64 *self, OutStream *outstream)
{
    OutStream_Write_C64(outstream, (uint64_t)self->value);
}

Integer64*
Int64_deserialize(Integer64 *self, InStream *instream)
{
    int64_t value = (int64_t)InStream_Read_C64(instream);
    return self ? Int64_init(self, value) : Int64_new(value);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

