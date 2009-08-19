#include "xs/XSBind.h"

#include "KinoSearch/Analysis/CaseFolder.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Obj/ByteBuf.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/StringHelper.h"

static size_t
S_lc_to_work_buf(kino_CaseFolder *self, chy_u8_t *source, size_t len,
                 chy_u8_t **buf, chy_u8_t **limit)
{
    kino_ByteBuf *const  work_buf   = self->work_buf;
    chy_u8_t            *dest       = *buf;
    chy_u8_t            *dest_start = dest;
    chy_u8_t *const      end        = source + len;
    chy_u8_t             utf8_buf[7];

    while (source < end) {
        STRLEN buf_utf8_len;
        (void)to_utf8_lower(source, utf8_buf, &buf_utf8_len);

        /* Grow if necessary. */
        if (((STRLEN)(*limit - dest)) < buf_utf8_len) {
            size_t    bytes_so_far = dest - dest_start;
            size_t    amount       = bytes_so_far + (end - source) + 10; 
            Kino_BB_Set_Size(work_buf, bytes_so_far);
            *buf       = (chy_u8_t*)Kino_BB_Grow(work_buf, amount);
            dest_start = *buf;
            dest       = dest_start + bytes_so_far;
            *limit     = dest_start + work_buf->cap;
        }
        memcpy(dest, utf8_buf, buf_utf8_len);

        source += KINO_STRHELP_UTF8_SKIP[*source];
        dest += buf_utf8_len;
    }

    {
        size_t size = dest - dest_start;
        Kino_BB_Set_Size(work_buf, size);
        return size;
    }
}

kino_Inversion*
kino_CaseFolder_transform(kino_CaseFolder *self, kino_Inversion *inversion)
{
    kino_Token *token;
    chy_u8_t *buf   = (chy_u8_t*)Kino_BB_Get_Buf(self->work_buf);
    chy_u8_t *limit = buf + Kino_BB_Get_Capacity(self->work_buf);
    while (NULL != (token = Kino_Inversion_Next(inversion))) {
        size_t size = S_lc_to_work_buf(self, (chy_u8_t*)token->text, 
            token->len, &buf, &limit);
        if (size > token->len) {
            KINO_FREEMEM(token->text);
            token->text = KINO_MALLOCATE(size + 1, char);
        }
        memcpy(token->text, buf, size);
        token->text[size] = '\0';
        token->len = size;
    }
    Kino_Inversion_Reset(inversion);
    return (kino_Inversion*)KINO_INCREF(inversion);
}

kino_Inversion*
kino_CaseFolder_transform_text(kino_CaseFolder *self, kino_CharBuf *text)
{
    kino_Inversion *retval;
    kino_Token *token;
    chy_u8_t *buf   = (chy_u8_t*)Kino_BB_Get_Buf(self->work_buf);
    chy_u8_t *limit = buf + Kino_BB_Get_Capacity(self->work_buf);
    size_t size = S_lc_to_work_buf(self, Kino_CB_Get_Ptr8(text), 
        Kino_CB_Get_Size(text), &buf, &limit);
    token = kino_Token_new((char*)buf, size, 0, size, 1.0f, 1);
    retval = kino_Inversion_new(token);
    KINO_DECREF(token);
    return retval;
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

