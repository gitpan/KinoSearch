/* KinoSearch/Util/MathUtils.h -- various math utilities
 * 
 * Provide various math related utilities, including endcoding/decoding
 * integers in guaranteed Big-endian byte order.
 */

#ifndef H_KINO_MATHUTILS
#define H_KINO_MATHUTILS 1

#include "charmony.h"

/* Encode an unsigned 32-bit integer as 4 bytes in the buffer provided, using
 * big-endian byte order. 
 */
void 
kino_Math_encode_bigend_u32(kino_u32_t aU32, void *vbuf);

/* Encode an unsigned 16-bit integer as 2 bytes in the buffer provided, using
 * big-endian byte order. 
 */
void 
kino_Math_encode_bigend_u16(kino_u16_t aU16, void *vbuf);

/* Interpret a sequence of bytes as a big-endian unsigned 32-bit int.
 */
kino_u32_t 
kino_Math_decode_bigend_u32(void *vbuf);

/* Interpret a sequence of bytes as a big-endian unsigned 16-bit int.
 */
kino_u16_t 
kino_Math_decode_bigend_u16(void *vbuf);

#ifdef KINO_USE_SHORT_NAMES
# define Math_encode_bigend_u32    kino_Math_encode_bigend_u32
# define Math_encode_bigend_u16    kino_Math_encode_bigend_u16
# define Math_decode_bigend_u32    kino_Math_decode_bigend_u32
# define Math_decode_bigend_u16    kino_Math_decode_bigend_u16
#endif

#endif /* H_KINO_MATHUTILS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

