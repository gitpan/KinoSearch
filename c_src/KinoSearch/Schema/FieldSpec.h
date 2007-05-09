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
    chy_bool_t     indexed;
    chy_bool_t     stored;
    chy_bool_t     analyzed;
    chy_bool_t     vectorized;
    chy_bool_t     binary;
    chy_bool_t     compressed;
    struct kino_Posting *posting;
};

/* Constructor.
 */
kino_FieldSpec*
kino_FSpec_new(const char *class_name);

void
kino_FSpec_destroy(kino_FieldSpec *self);
KINO_METHOD("Kino_FSpec_Destroy");

KINO_END_CLASS

#endif /* H_KINO_FIELDSpec */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

