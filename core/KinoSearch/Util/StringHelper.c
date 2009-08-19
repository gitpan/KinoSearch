#include <string.h>

#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Util/StringHelper.h"

#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Util/MemManager.h"

const u8_t UTF8_SKIP[] = {
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4
};

const u8_t UTF8_TRAILING[] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3
};

char* 
StrHelp_strndup(const char *source, size_t size) 
{
    char *ptr = MALLOCATE(size + 1, char);
    if (ptr == NULL) 
        THROW(ERR, "Out of memory");
    ptr[size] = '\0';
    memcpy(ptr, source, size);
    return ptr;
}

i32_t
StrHelp_string_diff(const char *a, const char *b, 
                    size_t a_len,  size_t b_len) 
{
    size_t i;
    const size_t len = a_len <= b_len ? a_len : b_len;

    for (i = 0; i < len; i++) {
        if (*a++ != *b++) 
            break;
    }
    return i;
}

i32_t
StrHelp_compare_strings(const char *a, const char *b, 
                        size_t a_len,  size_t b_len) 
{
    i32_t comparison = 0;
    const size_t len = a_len < b_len? a_len : b_len;

    if (a == NULL  || b == NULL)
        THROW(ERR, "Internal error: can't compare unallocated pointers");
    
    if (len > 0)
        comparison = memcmp(a, b, len);

    /* If a is a substring of b, it's less than b, so return a neg num. */
    if (comparison == 0) 
        comparison = a_len - b_len;

    return comparison;
}

static const char base36_chars[] = "0123456789abcdefghijklmnopqrstuvwxyz";

CharBuf*
StrHelp_to_base36(u32_t num) 
{
    char buffer[11];
    char *buf = buffer + 10;

    /* Null terminate. */
    *buf = '\0';

    /* Convert to base 36 characters. */
    do {
        *(--buf) = base36_chars[ num % 36 ];
        num /= 36;
    } while (num > 0);

    return CB_new_from_trusted_utf8(buf, strlen(buf));
}

/* This function is adapted from sample code in RFC 2640. */
bool_t
StrHelp_utf8_valid(const char *ptr, size_t size)
{
    const unsigned char *      buf = (const unsigned char*)ptr;
    const unsigned char *const end = buf + size;
    unsigned char byte2_range_mask = 0x00;
    unsigned char c;
    int trailing = 0;  /* Continuation bytes. */

    while (buf != end) {
        c = *buf++;
        if (trailing) {
            /* Does trailing byte follow UTF-8 format? */
            if ((c & 0xC0) == 0x80) {
                /* Need to check 2nd byte for proper range? */
                if (byte2_range_mask) {
                    /* Reset mask if byte passes, otherwise fail. */
                    if (c & byte2_range_mask) byte2_range_mask = 0x00;
                    else return false;
                }
                trailing--;
            } 
            else {
                return false;
            }
        }
        else if ((c & 0x80) == 0x00) { /* 1-byte UTF-8 */
            continue;
        }
        else if ((c & 0xE0) == 0xC0) { /* 2-byte UTF-8 */
            /* Verify UTF-8 byte in range. */
            if (c & 0x1E) trailing = 1;
            else return false;
        }
        else if ((c & 0xF0) == 0xE0) { /* 3-byte UTF-8 */
            if (!(c & 0x0F)) byte2_range_mask = 0x20;
            trailing = 2;
        } 
        else if ((c & 0xF8) == 0xF0) { /* 4-byte UTF-8 */
            if (!(c & 0x07)) byte2_range_mask = 0x30;
            trailing = 3;
        }
        else if ((c & 0xFC) == 0xF8) { /* 5-byte UTF-8 */
            if (!(c & 0x03)) byte2_range_mask = 0x38;
            trailing = 4;
        } 
        else if ((c & 0xFE) == 0xFC) { /* 6-byte UTF-8 */
            if (!(c & 0x01)) byte2_range_mask = 0x3C;
            trailing = 5;
        } 
        else {
            return false;
        }
    }

    return trailing == 0 ? true : false;
}

u32_t
StrHelp_encode_utf8_char(u32_t code_point, u8_t *buf)
{
    if (code_point <= 0x7F) { /* ASCII */
        buf[0] = (u8_t)code_point;
        return 1;
    }
    else if (code_point <= 0x07FF) { /* 2 byte range */
        buf[0] = (u8_t)(0xC0 | (code_point >> 6));
        buf[1] = (u8_t)(0x80 | (code_point & 0x3f));
        return 2;
    }
    else if (code_point <= 0xFFFF) { /* 3 byte range */
        buf[0] = (u8_t)(0xE0 | ( code_point >> 12       ));
        buf[1] = (u8_t)(0x80 | ((code_point >> 6) & 0x3F));
        buf[2] = (u8_t)(0x80 | ( code_point       & 0x3f));
        return 3;
    }
    else if (code_point <= 0x1FFFFF) { /* 4 byte range */
        buf[0] = (u8_t)(0xF0 | ( code_point >> 18        ));
        buf[1] = (u8_t)(0x80 | ((code_point >> 12) & 0x3F));
        buf[2] = (u8_t)(0x80 | ((code_point >> 6 ) & 0x3F));
        buf[3] = (u8_t)(0x80 | ( code_point        & 0x3f));
        return 4;
    }
    else {
        THROW(ERR, "Illegal Unicode code point: %u32", code_point);
        UNREACHABLE_RETURN(u32_t);
    }
}

bool_t
StrHelp_is_whitespace(u32_t code_point)
{
    switch (code_point) {
                 /* <control-0009>..<control-000D> */
    case 0x0009: case 0x000A: case 0x000B: case 0x000C: case 0x000D:
    case 0x0020: /* SPACE */
    case 0x0085: /* <control-0085>*/
    case 0x00A0: /* NO-BREAK SPACE */
    case 0x1680: /* OGHAM SPACE MARK */
    case 0x180E: /* MONGOLIAN VOWEL SEPARATOR */
                 /* EN QUAD..HAIR SPACE */
    case 0x2000: case 0x2001: case 0x2002: case 0x2003: case 0x2004: 
    case 0x2005: case 0x2006: case 0x2007: case 0x2008: case 0x2009: 
    case 0x200A:
    case 0x2028: /* LINE SEPARATOR*/
    case 0x2029: /* PARAGRAPH SEPARATOR*/
    case 0x202F: /* NARROW NO-BREAK SPACE*/
    case 0x205F: /* MEDIUM MATHEMATICAL SPACE*/
    case 0x3000: /* IDEOGRAPHIC SPACE*/
        return true;

    default:
        return false;
    }
}

u32_t
StrHelp_decode_utf8_char(const char *ptr)
{
    const u8_t *const string = (const u8_t*)ptr;
    u32_t retval = *string;
    int trailing = UTF8_TRAILING[retval];

    switch (trailing) {
        case 0:
            break;

        case 1: 
            retval =   ((retval    & 0x1F) << 6)
                     |  (string[1] & 0x3F);
            break;

        case 2: 
            retval =   ((retval    & 0x0F) << 12)
                     | ((string[1] & 0x3F) << 6)
                     |  (string[2] & 0x3F);
            break;

        case 3: 
            retval =   ((retval    & 0x07) << 18)
                     | ((string[1] & 0x3F) << 12)
                     | ((string[2] & 0x3F) << 6)
                     |  (string[3] & 0x3F);
            break;

        case 4: 
            retval =   ((retval    & 0x03) << 24)
                     | ((string[1] & 0x3F) << 18)
                     | ((string[2] & 0x3F) << 12)
                     | ((string[3] & 0x3F) << 6)
                     |  (string[4] & 0x3F);
            break;

        default:
            THROW(ERR, "unexpected value for trailing: %i32", (i32_t)trailing);
    }

    return retval;
}

const char*
StrHelp_back_utf8_char(const char *ptr, char *start)
{
    while (--ptr >= start) {
        if ((*ptr & 0xC0) != 0x80) return ptr;
    }
    return NULL;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

