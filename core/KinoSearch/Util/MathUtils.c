#include <string.h>
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Util/MathUtils.h"
#include "KinoSearch/Util/Err.h"

u32_t
Math_fibonacci(u32_t n) {
    u32_t result = 0;
    if (n > 46) {
        THROW("input %u32 too high", n);
    }
    else if (n < 2) {
        result = n;
    }
    else {
        result = Math_fibonacci(n - 1) + Math_fibonacci(n - 2);
    }
    return result;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

