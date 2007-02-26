#include <string.h>

#define KINO_USE_SHORT_NAMES

#include "KinoSearch/Util/StringHelper.h"

#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Carp.h"
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

char* 
StrHelp_strndup(const char *source, size_t len) 
{
    char *ptr = MALLOCATE(len + 1, char);
    if (ptr == NULL) 
        CONFESS("Out of memory");
    ptr[len] = '\0';
    memcpy(ptr, source, len);
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
        CONFESS("Internal error: can't compare unallocated pointers");
    
    if (len > 0)
        comparison = memcmp(a, b, len);

    /* if a is a substring of b, it's less than b, so return a neg num */
    if (comparison == 0) 
        comparison = a_len - b_len;

    return comparison;
}

static const char base36_chars[] = "0123456789abcdefghijklmnopqrstuvwxyz";

ByteBuf*
StrHelp_to_base36(kino_u32_t num) 
{
    char buffer[11];
    char *buf = buffer + 10;

    /* null terminate */
    *buf = '\0';

    /* convert to base 36 characters */
    do {
        *(--buf) = base36_chars[ num % 36 ];
        num /= 36;
    } while (num > 0);

    return BB_new_str(buf, strlen(buf));
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

