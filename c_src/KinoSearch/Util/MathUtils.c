#define KINO_USE_SHORT_NAMES

#include "KinoSearch/Util/MathUtils.h"

void 
Math_encode_bigend_u32(u32_t aU32, void *vbuf) 
{
    u8_t *const buf = (u8_t*)vbuf;
    * buf      = (aU32 & 0xff000000) >> 24;
    *(buf + 1) = (aU32 & 0x00ff0000) >> 16;
    *(buf + 2) = (aU32 & 0x0000ff00) >> 8;
    *(buf + 3) = (aU32 & 0x000000ff);
}

void 
Math_encode_bigend_u16(u16_t aU16, void *vbuf) 
{
    u8_t *const buf = (u8_t*)vbuf;
    * buf      = (aU16 & 0xff00) >> 8;
    *(buf + 1) = (aU16 & 0x00ff);
}

u32_t 
Math_decode_bigend_u32(void *vbuf) 
{
    u8_t *const buf = (u8_t*)vbuf;
    return (* buf      << 24) |
           (*(buf + 1) << 16) |
           (*(buf + 2) << 8)  |
            *(buf + 3);
}

u16_t 
Math_decode_bigend_u16(void *vbuf) 
{
    u8_t *const buf = (u8_t*)vbuf;
    return (*buf << 8) | *(buf + 1);
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

