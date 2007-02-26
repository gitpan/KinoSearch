#ifndef H_KINO_POSTING
#define H_KINO_POSTING 1

#include "KinoSearch/Util/Obj.r"

struct kino_ByteBuf;
typedef struct kino_Posting kino_Posting;
typedef struct KINO_POSTING_VTABLE KINO_POSTING_VTABLE;

KINO_CLASS("KinoSearch::Index::Posting", "Posting", "KinoSearch::Util::Obj");

struct kino_Posting {
    KINO_POSTING_VTABLE *_;
    kino_u32_t refcount;
    struct kino_ByteBuf  *stringified;
    kino_i32_t           *positions;
};

/* Starting with a serialized sting, unpack the members of the Posting.
 */
KINO_FUNCTION(
void
kino_Posting_deserialize(kino_Posting *self));

/* Convert the posting into an sortable, serialized ByteBuf.
 */
KINO_METHOD("Kino_Posting_Serialize",
struct kino_ByteBuf* 
kino_Posting_serialize(kino_Posting *self));

KINO_END_CLASS

#endif /* H_KINO_POSTING */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

