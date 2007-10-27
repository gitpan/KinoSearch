#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_REMOTEFIELDDOC_VTABLE
#include "KinoSearch/Search/RemoteFieldDoc.r"

RemoteFieldDoc*
RemoteFieldDoc_new(u32_t doc_num, float score, VArray *field_vals)
{
    CREATE(self, RemoteFieldDoc, REMOTEFIELDDOC);

    /* Assign. */
    self->doc_num    = doc_num;
    self->score      = score;
    self->field_vals = REFCOUNT_INC(field_vals);

    return self;
}

void
RemoteFieldDoc_serialize(RemoteFieldDoc *self, ByteBuf *target)
{
    char *ptr, *start;
    const size_t min_len = target->len 
                   + VINT_MAX_BYTES  /* doc_num */ 
                   + sizeof(float)   /* score */
                   + VINT_MAX_BYTES; /* number of fields */
    size_t new_len = min_len;
    u32_t i;

    /* Reserve space for field vals; extend target buffer. */
    for (i = 0; i < self->field_vals->size; i++) {
        ByteBuf *field_val = (ByteBuf*)VA_Fetch(self->field_vals, i);
        new_len += VINT_MAX_BYTES; /* index number */
        if (field_val != NULL)
            new_len +=  + field_val->len + VINT_MAX_BYTES; /* ser. ByteBuf */
    }
    BB_GROW(target, new_len);
    ptr = BBEND(target);
    start = ptr;

    /* doc_num, score, num_fields */
    ENCODE_VINT(self->doc_num, ptr);
    memcpy(ptr, &self->score, sizeof(float)); /* NOTE: This is NOT PORTABLE. */
    ptr += sizeof(float);
    ENCODE_VINT(self->field_vals->size, ptr);

    /* account for amount consumed */
    target->len += ptr - start;

    /* Field vals. */
    for (i = 0; i < self->field_vals->size; i++) {
        ByteBuf *field_val = (ByteBuf*)VA_Fetch(self->field_vals, i);
        if (field_val != NULL) {
            char *const fv_start = BBEND(target);
            char *fv_ptr = fv_start;
            ENCODE_VINT(i, fv_ptr);
            target->len += fv_ptr - fv_start;
            BB_Serialize(field_val, target);
        }
    }
}

RemoteFieldDoc*
RemoteFieldDoc_deserialize(ViewByteBuf *serialized)
{
    u32_t i, num_field_vals;
    CREATE(self, RemoteFieldDoc, REMOTEFIELDDOC);

    /* Sanity check. */
    if (serialized->len < 1 + sizeof(float) + 1)
        CONFESS("Not enough chars in serialization: %d", serialized->len);

    /* Decode doc_num. */
    DECODE_VINT(self->doc_num, serialized->ptr);

    /* Decode score. */
    memcpy(&self->score, serialized->ptr, sizeof(float));
    serialized->ptr += sizeof(float);
    serialized->len -= sizeof(float);

    /* Decode field values. */
    DECODE_VINT(num_field_vals, serialized->ptr);
    self->field_vals = VA_new(num_field_vals);
    for  (i = 0; i < num_field_vals; i++) { 
        u32_t ix;
        ByteBuf *field_val;

        DECODE_VINT(ix, serialized->ptr);
        if (i < ix) i = ix;
        field_val = BB_deserialize(serialized);
        VA_Store(self->field_vals, i, (Obj*)field_val);
        REFCOUNT_DEC(field_val);
    }

    return self;
}

void
RemoteFieldDoc_destroy(RemoteFieldDoc *self)
{
    REFCOUNT_DEC(self->field_vals);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

