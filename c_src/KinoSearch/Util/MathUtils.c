#include <string.h>
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Util/MathUtils.h"

u32_t 
Math_decode_bigend_u32(void *vbuf) 
{
    u32_t retval;
    u8_t *buf = (u8_t*)vbuf;
    MATH_DECODE_U32(retval, buf);
    return retval;
}

u16_t 
Math_decode_bigend_u16(void *vbuf) 
{
    u16_t retval;
    u8_t *buf = (u8_t*)vbuf;
    MATH_DECODE_U16(retval, buf);
    return retval;
}

u32_t
kino_Math_decode_vint(char **source_ptr)
{
    u32_t retval;
    u8_t *source = (u8_t*)*source_ptr;

    DECODE_VINT(retval, source);

    /* set passed-in ptr */
    *source_ptr = (char*)source;

    return retval;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

