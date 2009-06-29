#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/FieldType/NumericType.h"

NumericType*
NumType_init(NumericType *self)
{
    return NumType_init2(self, 1.0, true, true, false);
}

NumericType*
NumType_init2(NumericType *self, float boost, bool_t indexed, bool_t stored, 
              bool_t sortable)
{
    FType_init((FieldType*)self);
    self->boost      = boost;
    self->indexed    = indexed;
    self->stored     = stored;
    self->sortable   = sortable;
    return self;
}

bool_t
NumType_binary(NumericType *self)
{
    UNUSED_VAR(self);
    return true;
}

Hash*
NumType_dump_for_schema(NumericType *self) 
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "type", 4, (Obj*)NumType_Specifier(self));

    if (self->boost != 1.0) {
        Hash_Store_Str(dump, "boost", 5, (Obj*)CB_newf("%f64", self->boost));
    }
    Hash_Store_Str(dump, "indexed", 7, 
        (Obj*)CB_newf("%i32", (i32_t)self->indexed));
    Hash_Store_Str(dump, "stored", 6, 
        (Obj*)CB_newf("%i32", (i32_t)self->stored));
    Hash_Store_Str(dump, "sortable", 8, 
        (Obj*)CB_newf("%i32", (i32_t)self->sortable));

    return dump;
}

Hash*
NumType_dump(NumericType *self)
{
    Hash *dump = NumType_Dump_For_Schema(self);
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(Obj_Get_Class_Name(self)));
    return dump;
}

NumericType*
NumType_load(NumericType *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *class_name = (CharBuf*)Hash_Fetch_Str(source, "_class", 6);
    VTable *vtable = (class_name != NULL && OBJ_IS_A(class_name, CHARBUF)) 
                   ? VTable_singleton(class_name, NULL)
                   : (VTable*)&FLOAT64TYPE;
    NumericType *loaded = (NumericType*)VTable_Make_Obj(vtable);
    Obj *boost_dump   = Hash_Fetch_Str(source, "boost", 5);
    Obj *indexed_dump = Hash_Fetch_Str(source, "indexed", 7);
    Obj *stored_dump  = Hash_Fetch_Str(source, "stored", 6);
    Obj *sort_dump    = Hash_Fetch_Str(source, "sortable", 8);
    UNUSED_VAR(self);

    NumType_init(loaded);
    if (boost_dump)   { loaded->boost    = (float)Obj_To_F64(boost_dump);    }
    if (indexed_dump) { loaded->indexed  = (bool_t)Obj_To_I64(indexed_dump); }
    if (stored_dump)  { loaded->stored   = (bool_t)Obj_To_I64(stored_dump);  }
    if (sort_dump)    { loaded->sortable = (bool_t)Obj_To_I64(sort_dump);    }

    return loaded;
}

/****************************************************************************/

Float64Type*
Float64Type_new()
{
    Float64Type *self = (Float64Type*)VTable_Make_Obj(&FLOAT64TYPE);
    return Float64Type_init(self);
}

Float64Type*
Float64Type_init(Float64Type *self)
{
    return Float64Type_init2(self, 1.0, true, true, false);
}

Float64Type*
Float64Type_init2(Float64Type *self, float boost, bool_t indexed, 
                  bool_t stored, bool_t sortable)
{
    return (Float64Type*)NumType_init2((NumericType*)self, boost, indexed, 
        stored, sortable);
}

CharBuf*
Float64Type_specifier(Float64Type *self)
{
    UNUSED_VAR(self);
    return CB_newf("f64_t");
}

i8_t
Float64Type_primitive_id(Float64Type *self)
{
    UNUSED_VAR(self);
    return FType_FLOAT64;
}

Float64*
Float64Type_make_blank(Float64Type *self)
{
    UNUSED_VAR(self);
    return Float64_new(0.0);
}

bool_t
Float64Type_equals(Float64Type *self, Obj *other)
{
    if (self == (Float64Type*)other) { return true; }
    else {
        Float64Type_equals_t super_equals = (Float64Type_equals_t)
            SUPER_METHOD(&FLOAT64TYPE, Float64Type, Equals);
        return super_equals(self, other);
    }
}

/****************************************************************************/

Float32Type*
Float32Type_new()
{
    Float32Type *self = (Float32Type*)VTable_Make_Obj(&FLOAT32TYPE);
    return Float32Type_init(self);
}

Float32Type*
Float32Type_init(Float32Type *self)
{
    return Float32Type_init2(self, 1.0, true, true, false);
}

Float32Type*
Float32Type_init2(Float32Type *self, float boost, bool_t indexed, 
                  bool_t stored, bool_t sortable)
{
    return (Float32Type*)NumType_init2((NumericType*)self, boost, indexed, 
        stored, sortable);
}

CharBuf*
Float32Type_specifier(Float32Type *self)
{
    UNUSED_VAR(self);
    return CB_newf("f32_t");
}

i8_t
Float32Type_primitive_id(Float32Type *self)
{
    UNUSED_VAR(self);
    return FType_FLOAT32;
}

Float32*
Float32Type_make_blank(Float32Type *self)
{
    UNUSED_VAR(self);
    return Float32_new(0.0f);
}

bool_t
Float32Type_equals(Float32Type *self, Obj *other)
{
    if (self == (Float32Type*)other) { return true; }
    else {
        Float32Type_equals_t super_equals = (Float32Type_equals_t)
            SUPER_METHOD(&FLOAT32TYPE, Float32Type, Equals);
        return super_equals(self, other);
    }
}

/****************************************************************************/

Int32Type*
Int32Type_new()
{
    Int32Type *self = (Int32Type*)VTable_Make_Obj(&INT32TYPE);
    return Int32Type_init(self);
}

Int32Type*
Int32Type_init(Int32Type *self)
{
    return Int32Type_init2(self, 1.0, true, true, false);
}

Int32Type*
Int32Type_init2(Int32Type *self, float boost, bool_t indexed, 
                bool_t stored, bool_t sortable)
{
    return (Int32Type*)NumType_init2((NumericType*)self, boost, indexed, 
        stored, sortable);
}

CharBuf*
Int32Type_specifier(Int32Type *self)
{
    UNUSED_VAR(self);
    return CB_newf("i32_t");
}

i8_t
Int32Type_primitive_id(Int32Type *self)
{
    UNUSED_VAR(self);
    return FType_INT32;
}

Int32*
Int32Type_make_blank(Int32Type *self)
{
    UNUSED_VAR(self);
    return Int32_new(0);
}

bool_t
Int32Type_equals(Int32Type *self, Obj *other)
{
    if (self == (Int32Type*)other) { return true; }
    else {
        Int32Type_equals_t super_equals = (Int32Type_equals_t)
            SUPER_METHOD(&INT32TYPE, Int32Type, Equals);
        return super_equals(self, other);
    }
}

/****************************************************************************/

Int64Type*
Int64Type_new()
{
    Int64Type *self = (Int64Type*)VTable_Make_Obj(&INT64TYPE);
    return Int64Type_init(self);
}

Int64Type*
Int64Type_init(Int64Type *self)
{
    return Int64Type_init2(self, 1.0, true, true, false);
}

Int64Type*
Int64Type_init2(Int64Type *self, float boost, bool_t indexed, 
                bool_t stored, bool_t sortable)
{
    return (Int64Type*)NumType_init2((NumericType*)self, boost, indexed, 
        stored, sortable);
}

CharBuf*
Int64Type_specifier(Int64Type *self)
{
    UNUSED_VAR(self);
    return CB_newf("i64_t");
}

i8_t
Int64Type_primitive_id(Int64Type *self)
{
    UNUSED_VAR(self);
    return FType_INT64;
}

Int64*
Int64Type_make_blank(Int64Type *self)
{
    UNUSED_VAR(self);
    return Int64_new(0);
}

bool_t
Int64Type_equals(Int64Type *self, Obj *other)
{
    if (self == (Int64Type*)other) { return true; }
    else {
        Int64Type_equals_t super_equals = (Int64Type_equals_t)
            SUPER_METHOD(&INT64TYPE, Int64Type, Equals);
        return super_equals(self, other);
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

