#define KINO_USE_SHORT_NAMES

#include <string.h>
#include "KinoSearch/Util/MergeSort.h"
#include "KinoSearch/Util/ByteBuf.r"

void
MSort_mergesort(ByteBuf **elems, ByteBuf **scratch, u32_t num_elems) 
{
    if (num_elems == 0)
        return;
    MSort_do_sort(elems, scratch, 0, num_elems - 1);
}

void
MSort_do_sort(ByteBuf **elems, ByteBuf **scratch, u32_t left, u32_t right)
{
    if (right > left) {
        const u32_t mid = ( (right+left)/2 ) + 1;
        MSort_do_sort(elems, scratch, left, mid - 1);
        MSort_do_sort(elems, scratch, mid,  right);
        MSort_merge( (elems + left),  (mid - left), 
                  (elems + mid), (right - mid + 1), scratch);
        memcpy((elems + left), scratch,
            ((right - left + 1) * sizeof(ByteBuf*)) );
    }
}

void
MSort_merge(ByteBuf **left_ptr,  u32_t left_size,
            ByteBuf **right_ptr, u32_t right_size,
            ByteBuf **dest) 
{
    ByteBuf **left_boundary  = left_ptr  + left_size;
    ByteBuf **right_boundary = right_ptr + right_size;

    while (left_ptr < left_boundary && right_ptr < right_boundary) {
        if (BB_compare(left_ptr, right_ptr) < 1) {
            *dest++ = *left_ptr++;
        }
        else {
            *dest++ = *right_ptr++;
        }
    }
    while (left_ptr < left_boundary) {
        *dest++ = *left_ptr++;
    }
    while (right_ptr < right_boundary) {
        *dest++ = *right_ptr++;
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

