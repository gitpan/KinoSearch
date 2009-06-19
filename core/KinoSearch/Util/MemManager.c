#include <stdlib.h>
#include <stdio.h>
#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/MemManager.h"

void*
MemMan_wrapped_malloc(size_t count)
{
    void *pointer = malloc(count);
    if (pointer == NULL && count != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void*
MemMan_wrapped_calloc(size_t count, size_t size)
{
    void *pointer = calloc(count, size);
    if (pointer == NULL && count != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void*
MemMan_wrapped_realloc(void *ptr, size_t size)
{
    void *pointer = realloc(ptr, size);
    if (pointer == NULL && size != 0) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    return pointer;
}

void
kino_MemMan_wrapped_free(void *ptr)
{
    free(ptr);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

