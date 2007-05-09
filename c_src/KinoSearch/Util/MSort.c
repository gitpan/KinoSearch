#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include "KinoSearch/Util/MSort.h"
#include "KinoSearch/Util/ByteBuf.r"

void
MSort_mergesort(void *elems, void *scratch, u32_t num_elems,
                MSort_compare_t compare, void *context) 
{
    if (num_elems == 0)
        return;
    MSort_do_sort(elems, scratch, 0, num_elems - 1, compare, context);
}

void
MSort_do_sort(void *elems_orig, void *scratch_orig, u32_t left, u32_t right,
              MSort_compare_t compare, void *context)
{
    int** elems     = (int**)elems_orig;
    int** scratch   = (int**)scratch_orig;
    if (right > left) {
        const u32_t mid = ( (right+left)/2 ) + 1;
        MSort_do_sort(elems, scratch, left, mid - 1, compare, context);
        MSort_do_sort(elems, scratch, mid,  right, compare, context);
        MSort_merge( (elems + left),  (mid - left), 
            (elems + mid), (right - mid + 1), scratch, compare, context);
        memcpy((elems + left), scratch,
            ((right - left + 1) * sizeof(int*)) );
    }
}

void
MSort_merge(void *left_ptr_orig,  u32_t left_size,
            void *right_ptr_orig, u32_t right_size,
            void *dest_orig, MSort_compare_t compare, void *context) 
{
    /* pretend everything's an int** */
    int **left_ptr       = (int**)left_ptr_orig;
    int **right_ptr      = (int**)right_ptr_orig;
    int **dest           = (int**)dest_orig;
    int **left_boundary  = left_ptr  + left_size;
    int **right_boundary = right_ptr + right_size;

    while (left_ptr < left_boundary && right_ptr < right_boundary) {
        if (compare(context, left_ptr, right_ptr) < 1) {
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

