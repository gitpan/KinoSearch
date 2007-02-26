#ifndef H_KINO_TERM
#define H_KINO_TERM 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Term kino_Term;
typedef struct KINO_TERM_VTABLE KINO_TERM_VTABLE;

struct kino_ByteBuf;
struct kino_ViewByteBuf;

KINO_CLASS("KinoSearch::Index::Term", "Term", "KinoSearch::Util::Obj");

struct kino_Term {
    KINO_TERM_VTABLE *_;
    kino_u32_t refcount;
    struct kino_ByteBuf *field;
    struct kino_ByteBuf *text;
};

KINO_FUNCTION(
kino_Term*
kino_Term_new(const struct kino_ByteBuf *field, 
              const struct kino_ByteBuf *text));

/* Constructor for internal use only.
 */
KINO_FUNCTION(
kino_Term*
kino_Term_new_str(const char *field, const char *text));

KINO_FUNCTION(
kino_Term*
kino_Term_deserialize(struct kino_ViewByteBuf *serialized));

KINO_METHOD("Kino_Term_Get_Field",
struct kino_ByteBuf*
kino_Term_get_field(kino_Term *self));

KINO_METHOD("Kino_Term_Get_Text",
struct kino_ByteBuf*
kino_Term_get_text(kino_Term *self));

KINO_METHOD("Kino_Term_Copy",
void
kino_Term_copy(kino_Term *self, kino_Term *other));

KINO_METHOD("Kino_Term_To_String",
struct kino_ByteBuf*
kino_Term_to_string(kino_Term *self));

KINO_METHOD("Kino_Term_Clone",
kino_Term*
kino_Term_clone(kino_Term *self));

KINO_METHOD("Kino_Term_Equals",
kino_bool_t
kino_Term_equals(kino_Term *self, kino_Term *other));

KINO_METHOD("Kino_Term_Destroy",
void
kino_Term_destroy(kino_Term *self));

KINO_METHOD("Kino_Term_Serialize",
void
kino_Term_serialize(kino_Term *self, struct kino_ByteBuf *target));

KINO_END_CLASS

#endif /* H_KINO_TERM */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

