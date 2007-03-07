#ifndef H_KINO_FIELDSPEC
#define H_KINO_FIELDSPEC 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_FieldSpec kino_FieldSpec;
typedef struct KINO_FIELDSPEC_VTABLE KINO_FIELDSPEC_VTABLE;

struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Schema::FieldSpec", "FSpec", 
    "KinoSearch::Util::Obj");

struct kino_FieldSpec {
    KINO_FIELDSPEC_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    float          boost;
    kino_bool_t    indexed;
    kino_bool_t    stored;
    kino_bool_t    analyzed;
    kino_bool_t    vectorized;
    kino_bool_t    binary;
    kino_bool_t    compressed;
    kino_bool_t    store_field_boost;
    kino_bool_t    store_freq;
    kino_bool_t    store_position;
    kino_bool_t    store_pos_boost;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_FieldSpec*
kino_FSpec_new(const char *class_name));

KINO_METHOD("Kino_FSpec_Destroy",
void
kino_FSpec_destroy(kino_FieldSpec *self));

KINO_END_CLASS

#endif /* H_KINO_FIELDSpec */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

