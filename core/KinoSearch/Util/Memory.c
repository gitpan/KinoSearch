#define C_KINO_MEMORY
#include <stdlib.h>
#include <stdio.h>
#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/Memory.h"

void*
Memory_wrapped_malloc(size_t count)
{
    void *pointer = malloc(count);
    if (pointer == NULL && count != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void*
Memory_wrapped_calloc(size_t count, size_t size)
{
    void *pointer = calloc(count, size);
    if (pointer == NULL && count != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void*
Memory_wrapped_realloc(void *ptr, size_t size)
{
    void *pointer = realloc(ptr, size);
    if (pointer == NULL && size != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void
kino_Memory_wrapped_free(void *ptr)
{
    free(ptr);
}

#ifndef SIZE_MAX
#define SIZE_MAX ((size_t)-1)
#endif

size_t
Memory_oversize(size_t minimum)
{
    size_t extra = minimum / 8;
    uint64_t amount = minimum + extra;
    return amount > SIZE_MAX ? SIZE_MAX : (size_t)amount;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

