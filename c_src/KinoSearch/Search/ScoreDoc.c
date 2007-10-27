#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREDOC_VTABLE
#include "KinoSearch/Search/ScoreDoc.r"

ScoreDoc*
ScoreDoc_new(u32_t doc_num, float score)
{
    CREATE(self, ScoreDoc, SCOREDOC);
    self->doc_num     = doc_num;
    self->score       = score;
    return self;
}

void
ScoreDoc_serialize(ScoreDoc *self, ByteBuf *target)
{
    char *ptr;
    size_t new_len = target->len + sizeof(u32_t) + sizeof(float);

    /* add space */
    BB_GROW(target, new_len);
    ptr = BBEND(target);
    target->len = new_len;

    /* doc_num */
    MATH_ENCODE_U32(self->doc_num, ptr);
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
    MATH_DECODE_U32(self->doc_num, serialized->ptr);
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

