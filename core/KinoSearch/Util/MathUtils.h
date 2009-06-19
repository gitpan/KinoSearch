/* KinoSearch/Util/MathUtils.h -- various math utilities
 * 
 * Provide various math related utilities, including endcoding/decoding of
 * C32s and integers in guaranteed Big-endian byte order.
 */

#ifndef H_KINO_MATHUTILS
#define H_KINO_MATHUTILS 1

#include "charmony.h"

/* Return the fibonacci number for [num].  Throws an error if [num] is greater
 * than 46.
 */
chy_u32_t
kino_Math_fibonacci(chy_u32_t num);

/** Encode an unsigned 32-bit integer as 4 bytes in the buffer provided, using
 * big-endian byte order.  Advance buffer pointer by 4 bytes.
 */
static CHY_INLINE void
kino_Math_encode_bigend_u32(chy_u32_t num, void *dest_ptr)
{
    chy_u8_t *dest = *(chy_u8_t**)dest_ptr;
#ifdef CHY_BIG_END
    memcpy(dest, &num, sizeof(chy_u32_t));
#else /* little endian */
    dest[0] = (num & 0xff000000) >> 24;
    dest[1] = (num & 0x00ff0000) >> 16;
    dest[2] = (num & 0x0000ff00) >> 8;
    dest[3] = (num & 0x000000ff);
#endif /* CHY_BIG_END (and little endian) */
}

/* Interpret a sequence of bytes as a big-endian unsigned 32-bit int.  The
 * buffer need not be aligned to word size.  
 */
static CHY_INLINE chy_u32_t
kino_Math_decode_bigend_u32(void *source)
{
    chy_u8_t *const buf = (chy_u8_t*)source;
    return  (buf[0]  << 24) |
            (buf[1]  << 16) |
            (buf[2]  << 8)  |
            (buf[3]);
}

static CHY_INLINE chy_u64_t
kino_Math_decode_bigend_u64(void *source)
{
    chy_u8_t *const buf = (chy_u8_t*)source;
    chy_u64_t high_bits = (buf[0]  << 24) |
                          (buf[1]  << 16) |
                          (buf[2]  << 8)  |
                          (buf[3]);
    chy_u32_t low_bits  = (buf[4]  << 24) |
                          (buf[5]  << 16) |
                          (buf[6]  << 8)  |
                          (buf[7]);
    chy_u64_t retval = high_bits << 32;
    retval |= low_bits;
    return retval;
}

#define KINO_MATH_C32_MAX_BYTES  ((sizeof(chy_u32_t) * 8 / 7) + 1)   /* 5 */
#define KINO_MATH_C64_MAX_BYTES ((sizeof(chy_u64_t) * 8 / 7) + 1)   /* 10 */

/* Encode a C32 at the space pointed to by the provided pointer, which must
 * be either a char* or a uchar*.  The pointer will be advanced to immediately
 * after the end of the C32.
 */
static CHY_INLINE void
kino_Math_encode_c32(chy_u32_t number, char **out_buf)
{
    chy_u8_t   buf[KINO_MATH_C32_MAX_BYTES];
    chy_u32_t  aU32        = number;
    chy_u8_t  *const limit = buf + sizeof(buf);
    chy_u8_t  *ptr         = limit - 1;
    int        num_bytes;
    /* Write last byte first, which has no continue bit. */
    *ptr = aU32 & 0x7f;
    aU32 >>= 7;
    while (aU32) {
        /* Work backwards, writing bytes with continue bits set. */
        *--ptr = ((aU32 & 0x7f) | 0x80);
        aU32 >>= 7;
    }
    num_bytes = limit - ptr;
    memcpy(*out_buf, ptr, num_bytes);
    *out_buf += num_bytes;
}

/** Encode a C32 as above, but add "leading zeroes" so that the space
 * consumed will always be 5 bytes.
 */
static CHY_INLINE void
kino_Math_encode_padded_c32(chy_u32_t number, char **out_buf)
{
    chy_u8_t buf[KINO_MATH_C32_MAX_BYTES]
        = { 0x80, 0x80, 0x80, 0x80, 0x80 };
    chy_u32_t aU32        = number;
    chy_u8_t *const limit = buf + sizeof(buf);
    chy_u8_t *ptr         = limit - 1;
    /* Write last byte first, which has no continue bit. */
    *ptr = aU32 & 0x7f;
    aU32 >>= 7;
    while (aU32) {
        /* Work backwards, writing bytes with continue bits set. */
        *--ptr = ((aU32 & 0x7f) | 0x80);
        aU32 >>= 7;
    }
    memcpy(*out_buf, buf, KINO_MATH_C32_MAX_BYTES);
    *out_buf += sizeof(buf);
}

/* Decode a compressed integer up to size of 'var', advancing 'source' */
#define KINO_MATH_DECODE(var, source) \
    do { \
        var = (*source & 0x7f); \
        while (*source++ & 0x80) { \
            var = (*source & 0x7f) | (var << 7); \
        }  \
    } while (0)

/** Read a compressed 32-bit integer from the buffer pointed to by the source
 * pointer.  Advance the pointer, consuming the bytes occupied by the C32.
 */
static CHY_INLINE chy_u32_t
kino_Math_decode_c32(char **source_ptr)
{
    char *source = *source_ptr;
    chy_u32_t decoded = (*source & 0x7f); 
    KINO_MATH_DECODE(decoded, source);
    *source_ptr = source;
    return decoded;
}

/** Read a compressed 64-bit integer from the buffer pointed to by the source
 * pointer.  Advance the pointer, consuming the bytes occupied by the C32.
 */
static CHY_INLINE chy_u64_t
kino_Math_decode_c64(char **source_ptr)
{
    char *source = *source_ptr;
    chy_u64_t decoded = (*source & 0x7f); 
    KINO_MATH_DECODE(decoded, source);
    *source_ptr = source;
    return decoded;
}

/* Advance a pointer past one encoded C32.
 */
static CHY_INLINE void
kino_Math_skip_c32(char **source_ptr)
{
    chy_u8_t *ptr = *(chy_u8_t**)source_ptr;
    while ((*ptr++ & 0x80) != 0) { }
    *source_ptr = (char*)ptr;
}

#ifdef KINO_USE_SHORT_NAMES
  #define Math_encode_bigend_u32    kino_Math_encode_bigend_u32
  #define Math_decode_bigend_u32    kino_Math_decode_bigend_u32
  #define Math_decode_bigend_u64    kino_Math_decode_bigend_u64
  #define C32_MAX_BYTES             KINO_MATH_C32_MAX_BYTES
  #define C64_MAX_BYTES             KINO_MATH_C64_MAX_BYTES
  #define Math_encode_c32           kino_Math_encode_c32
  #define Math_encode_padded_c32    kino_Math_encode_padded_c32 
  #define Math_decode_c32           kino_Math_decode_c32
  #define Math_decode_c64           kino_Math_decode_c64
  #define Math_skip_c32             kino_Math_skip_c32
  #define Math_fibonacci            kino_Math_fibonacci
#endif

#endif /* H_KINO_MATHUTILS */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

