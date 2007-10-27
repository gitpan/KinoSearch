#ifndef H_KINO_REMOTEFIELDDOC
#define H_KINO_REMOTEFIELDDOC 1

#include "KinoSearch/Search/ScoreDoc.r"

typedef struct kino_RemoteFieldDoc kino_RemoteFieldDoc;
typedef struct KINO_REMOTEFIELDDOC_VTABLE KINO_REMOTEFIELDDOC_VTABLE;

KINO_CLASS("KinoSearch::Search::RemoteFieldDoc", "RemoteFieldDoc",
    "KinoSearch::Search::ScoreDoc");

struct kino_RemoteFieldDoc {
    KINO_REMOTEFIELDDOC_VTABLE *_;
    KINO_SCOREDOC_MEMBER_VARS;
    struct kino_VArray *field_vals;
};

/* Constructor
 */
kino_RemoteFieldDoc*
kino_RemoteFieldDoc_new(chy_u32_t doc_num, float score, 
                        struct kino_VArray *field_vals);

void
kino_RemoteFieldDoc_serialize(kino_RemoteFieldDoc *self, kino_ByteBuf *target);
KINO_METHOD("Kino_RemoteFieldDoc_Serialize");

kino_RemoteFieldDoc*
kino_RemoteFieldDoc_deserialize(kino_ViewByteBuf *serialized);
KINO_METHOD("Kino_RemoteFieldDoc_Deserialize");

void
kino_RemoteFieldDoc_destroy(kino_RemoteFieldDoc *self);
KINO_METHOD("Kino_RemoteFieldDoc_Destroy");

KINO_END_CLASS

#endif /* H_KINO_REMOTEFIELDDOC */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

