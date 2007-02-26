#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREDOC_VTABLE
#include "KinoSearch/Search/ScoreDoc.r"

ScoreDoc*
ScoreDoc_new(kino_u32_t id, float score)
{
    CREATE(self, ScoreDoc, SCOREDOC);
    self->id      = id;
    self->score   = score;
    return self;
}

void
ScoreDoc_serialize(ScoreDoc *self, ByteBuf *target)
{
    char *ptr;
    size_t new_len = target->len + sizeof(u32_t) + sizeof(float);

    /* add space */
    BB_Grow(target, new_len);
    ptr = BBEND(target);
    target->len = new_len;

    /* doc_num */
    Math_encode_bigend_u32(self->id, ptr);
    ptr += sizeof(u32_t);

    /* score */
    /* NOTE: This is NOT PORTABLE. */
    memcpy(ptr, &self->score, sizeof(float));
}

ScoreDoc*
ScoreDoc_deserialize(ViewByteBuf *serialized)
{
    CREATE(self, ScoreDoc, SCOREDOC);

    /* sanity check */
    if (serialized->len < sizeof(u32_t) + sizeof(float))
        CONFESS("Not enough chars in serialization: %d", serialized->len);

    /* decode doc_num */
    self->id = Math_decode_bigend_u32(serialized->ptr);
    serialized->ptr += sizeof(u32_t);
    serialized->len -= sizeof(u32_t);

    /* decode score */
    memcpy(&self->score, serialized->ptr, sizeof(float));
    serialized->ptr += sizeof(float);
    serialized->len -= sizeof(float);

    return self;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

