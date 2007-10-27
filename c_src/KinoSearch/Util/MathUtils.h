/* KinoSearch/Util/MathUtils.h -- various math utilities
 * 
 * Provide various math related utilities, including endcoding/decoding of
 * VInts and integers in guaranteed Big-endian byte order.
 */

#ifndef H_KINO_MATHUTILS
#define H_KINO_MATHUTILS 1

#include "charmony.h"

#ifdef CHY_BIG_END

/* Encode an unsigned 32-bit integer as 4 bytes in the buffer provided, using
 * big-endian byte order.  Advance buffer pointer by 4 bytes.
 */
  #define KINO_MATH_ENCODE_U32(_num, _dest) \
    do { \
        if (sizeof(_num) == sizeof(chy_u32_t)) { \
            memcpy(_dest, &_num, sizeof(chy_u32_t)); \
        } \
        else { \
            const chy_u32_t _num_copy = _num; \
            memcpy(_dest, &_num_copy, sizeof(chy_u32_t)); \
        } \
    } while (0)

/* Encode an unsigned 16-bit integer as 2 bytes in the buffer provided, using
 * big-endian byte order.  Advance buffer pointer by 2 bytes.
 */
  #define KINO_MATH_ENCODE_U16(_num, _dest) \
    do { \
        if (sizeof(_num) == sizeof(chy_u16_t)) { \
            memcpy(_dest, &_num, sizeof(chy_u16_t)); \
        } \
        else { \
            const chy_u16_t _num_copy = _num; \
            memcpy(_dest, &_num_copy, sizeof(chy_u16_t)); \
        } \
    } while (0)
    
#else /* little endian */

  #define KINO_MATH_ENCODE_U32(_num, _dest) \
    do { \
        const u32_t _num_copy  = _num; \
        u8_t *const _dest_copy = (u8_t*)_dest; \
        _dest_copy[0] = (_num_copy & 0xff000000) >> 24; \
        _dest_copy[1] = (_num_copy & 0x00ff0000) >> 16; \
        _dest_copy[2] = (_num_copy & 0x0000ff00) >> 8; \
        _dest_copy[3] = (_num_copy & 0x000000ff); \
    } while (0)

  #define KINO_MATH_ENCODE_U16(_num, _dest) \
    do { \
        const u16_t _num_copy  = _num; \
        u8_t *const _dest_copy = (u8_t*)_dest; \
        _dest_copy[0] = (_num_copy & 0xff00) >> 8; \
        _dest_copy[1] = (_num_copy & 0x000000ff); \
    } while (0)

#endif /* CHY_BIG_END (and little endian) */

/* Interpret a sequence of bytes as a big-endian unsigned 32-bit int.  The
 * buffer need not be aligned to word size.  
 */
#define KINO_MATH_DECODE_U32(_num, _source) \
    do { \
        u8_t *const _buf = (u8_t*)_source; \
        _num =  (_buf[0]  << 24) | \
                (_buf[1]  << 16) | \
                (_buf[2]  << 8)  | \
                (_buf[3]); \
    } while (0)

/* Wrapper around DECODE_U32 suitable for C89 initialization.
 */
chy_u32_t 
kino_Math_decode_bigend_u32(void *vbuf);

/* Interpret a sequence of bytes as a big-endian unsigned 16-bit int.  The
 * buffer need not be aligned to word size.  
 */
#define KINO_MATH_DECODE_U16(_num, _source) \
    do { \
        u8_t *const _buf = (u8_t*)_source; \
        _num = (_buf[0] << 8) | _buf[1]; \
    } while (0)

/* Wrapper around DECODE_U16 suitable for C89 initialization.
 */
chy_u16_t 
kino_Math_decode_bigend_u16(void *vbuf);

#define KINO_MATH_VINT_MAX_BYTES  ((sizeof(u32_t) * 8 / 7) + 1)   /* 5 */
#define KINO_MATH_VLONG_MAX_BYTES ((sizeof(u64_t) * 8 / 7) + 1)   /* 10 */

/* Encode a VInt at the space pointed to by the provided pointer, which must
 * be either a char* or a uchar*.  The pointer will be advanced to immediately
 * after the end of the VInt.
 */
#define KINO_MATH_ENCODE_VINT(_number, _out_buf) \
    do { \
        chy_u8_t _buf[KINO_MATH_VINT_MAX_BYTES]; \
        chy_u32_t _aU32        = _number; \
        chy_u8_t *const _limit = _buf + sizeof(_buf); \
        chy_u8_t *_ptr         = _limit - 1; \
        int       _num_bytes; \
        /* write last byte first, which has no continue bit */ \
        *_ptr = _aU32 & 0x7f; \
        _aU32 >>= 7; \
        while (_aU32) { \
            /* work backwards, writing bytes with continue bits set */ \
            *--_ptr = ((_aU32 & 0x7f) | 0x80); \
            _aU32 >>= 7; \
        } \
        _num_bytes = _limit - _ptr; \
        memcpy(_out_buf, _ptr, _num_bytes); \
        _out_buf += _num_bytes; \
    } while (0)

/* Same as above, but using 64-bit vars.
 */
#define KINO_MATH_ENCODE_VLONG(_number, _out_buf) \
    do { \
        chy_u8_t _buf[KINO_MATH_VLONG_MAX_BYTES]; \
        chy_u64_t _aQuad       = _number; \
        chy_u8_t *const _limit = _buf + sizeof(_buf); \
        chy_u8_t *_ptr         = _limit - 1; \
        int       _num_bytes; \
        /* write last byte first, which has no continue bit */ \
        *_ptr = _aQuad & 0x7f; \
        _aQuad >>= 7; \
        while (_aQuad) { \
            /* work backwards, writing bytes with continue bits set */ \
            *--_ptr = ((_aQuad & 0x7f) | 0x80); \
            _aQuad >>= 7; \
        } \
        _num_bytes = _limit - _ptr; \
        memcpy(_out_buf, _ptr, _num_bytes); \
        _out_buf += _num_bytes; \
    } while (0)

/* Encode a VInt, as above, but add "leading zeroes" so that the space
 * consumed will always be 5 bytes.
 */
#define KINO_MATH_ENCODE_FULL_VINT(_number, _out_buf) \
    do { \
        chy_u8_t _buf[KINO_MATH_VINT_MAX_BYTES] \
            = { 0x80, 0x80, 0x80, 0x80, 0x80 }; \
        chy_u32_t _aU32        = _number; \
        chy_u8_t *const _limit = _buf + sizeof(_buf); \
        chy_u8_t *_ptr         = _limit - 1; \
        /* write last byte first, which has no continue bit */ \
        *_ptr = _aU32 & 0x7f; \
        _aU32 >>= 7; \
        while (_aU32) { \
            /* work backwards, writing bytes with continue bits set */ \
            *--_ptr = ((_aU32 & 0x7f) | 0x80); \
            _aU32 >>= 7; \
        } \
        memcpy(_out_buf, _buf, KINO_MATH_VINT_MAX_BYTES); \
    } while (0)

/* Read a varible integer from the buffer pointed to by the source pointer.
 * While reading, advance the pointer, consuming the bytes occupied by the
 * VInt.
 */
#define KINO_MATH_DECODE_VINT(_var, _source_ptr) \
    do { \
        _var = 0; \
        do { \
            _var = (_var << 7) | (*(chy_u8_t*)(_source_ptr) & 0x7f); \
        } while ((*(chy_u8_t*)((_source_ptr)++) & 0x80) != 0); \
    } while (0)

/* So long as _var is a u64_t, the VINT macro works for a VLong as well.
 */
#define KINO_MATH_DECODE_VLONG KINO_MATH_DECODE_VINT

/* Wrapper function for DECODE_VINT suitable C89 initialization.
 */
chy_u32_t
kino_Math_decode_vint(char **source_ptr);

/* Advance a pointer past one encoded VInt.
 */
#define KINO_MATH_SKIP_VINT(_source_ptr) \
    do { \
        while ((*(chy_u8_t*)((_source_ptr)++) & 0x80) != 0) { } \
    } while (0)

#ifdef KINO_USE_SHORT_NAMES
  #define MATH_ENCODE_U32           KINO_MATH_ENCODE_U32
  #define MATH_ENCODE_U16           KINO_MATH_ENCODE_U16
  #define MATH_DECODE_U32           KINO_MATH_DECODE_U32
  #define MATH_DECODE_U16           KINO_MATH_DECODE_U16
  #define Math_decode_bigend_u32    kino_Math_decode_bigend_u32
  #define Math_decode_bigend_u16    kino_Math_decode_bigend_u16
  #define VINT_MAX_BYTES            KINO_MATH_VINT_MAX_BYTES
  #define VLONG_MAX_BYTES           KINO_MATH_VLONG_MAX_BYTES
  #define ENCODE_VINT               KINO_MATH_ENCODE_VINT
  #define ENCODE_VLONG              KINO_MATH_ENCODE_VLONG
  #define ENCODE_FULL_VINT          KINO_MATH_ENCODE_FULL_VINT
  #define DECODE_VINT               KINO_MATH_DECODE_VINT
  #define DECODE_VLONG              KINO_MATH_DECODE_VLONG
  #define Math_decode_vint          kino_Math_decode_vint
  #define SKIP_VINT                 KINO_MATH_SKIP_VINT
#endif

#endif /* H_KINO_MATHUTILS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

