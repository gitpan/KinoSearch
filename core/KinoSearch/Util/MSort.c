#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include "KinoSearch/Util/MSort.h"
#include "KinoSearch/Util/Err.h"

/* Classic mergesort functions for handling 4 and 8 byte elements,
 * respectively.
 */
static void
S_do_sort4(void *elems_orig, void *scratch_orig, u32_t left, u32_t right,
         MSort_compare_t compare, void *context);
static void
S_do_sort8(void *elems_orig, void *scratch_orig, u32_t left, u32_t right,
           MSort_compare_t compare, void *context);

void
MSort_mergesort(void *elems, void *scratch, 
                u32_t num_elems, u32_t bytes_per_elem,
                MSort_compare_t compare, void *context) 
{
    /* Bail if no items to sort. */
    if (num_elems == 0) { return; }

    /* Validate. */
    if (num_elems >= I32_MAX) {
        THROW("%u32 elems is more than max of %i32", num_elems, I32_MAX);
    }

    /* Dispatch by element size. */
    if (bytes_per_elem == 4) 
        S_do_sort4(elems, scratch, 0, num_elems - 1, compare, context);
    else if (bytes_per_elem == 8)
        S_do_sort8(elems, scratch, 0, num_elems - 1, compare, context);
    else 
        THROW("Can't sort elements which are %u32 bytes", bytes_per_elem);
}

/* The only significance of using i32_t and i64_t is that they are 4 and 8
 * bytes.
 */
#define FOUR_BYTE_TYPE  i32_t
#define EIGHT_BYTE_TYPE i64_t

static void
S_do_sort4(void *elems_orig, void *scratch_orig, u32_t left, u32_t right,
           MSort_compare_t compare, void *context)
{
    FOUR_BYTE_TYPE* elems     = (FOUR_BYTE_TYPE*)elems_orig;
    FOUR_BYTE_TYPE* scratch   = (FOUR_BYTE_TYPE*)scratch_orig;
    if (right > left) {
        const u32_t mid = ( (right+left)/2 ) + 1;
        S_do_sort4(elems, scratch, left, mid - 1, compare, context);
        S_do_sort4(elems, scratch, mid,  right, compare, context);
        MSort_merge4( (elems + left),  (mid - left), 
            (elems + mid), (right - mid + 1), scratch, compare, context);
        memcpy((elems + left), scratch,
            ((right - left + 1) * sizeof(FOUR_BYTE_TYPE)) );
    }
}

static void
S_do_sort8(void *elems_orig, void *scratch_orig, u32_t left, u32_t right,
         MSort_compare_t compare, void *context)
{
    EIGHT_BYTE_TYPE* elems     = (EIGHT_BYTE_TYPE*)elems_orig;
    EIGHT_BYTE_TYPE* scratch   = (EIGHT_BYTE_TYPE*)scratch_orig;
    if (right > left) {
        const u32_t mid = ( (right+left)/2 ) + 1;
        S_do_sort8(elems, scratch, left, mid - 1, compare, context);
        S_do_sort8(elems, scratch, mid,  right, compare, context);
        MSort_merge8( (elems + left),  (mid - left), 
            (elems + mid), (right - mid + 1), scratch, compare, context);
        memcpy((elems + left), scratch,
            ((right - left + 1) * sizeof(EIGHT_BYTE_TYPE)) );
    }
}

void
MSort_merge4(void *left_ptr_orig,  u32_t left_size,
            void *right_ptr_orig, u32_t right_size,
            void *dest_orig, MSort_compare_t compare, void *context) 
{
    FOUR_BYTE_TYPE *left_ptr       = (FOUR_BYTE_TYPE*)left_ptr_orig;
    FOUR_BYTE_TYPE *right_ptr      = (FOUR_BYTE_TYPE*)right_ptr_orig;
    FOUR_BYTE_TYPE *dest           = (FOUR_BYTE_TYPE*)dest_orig;
    FOUR_BYTE_TYPE *left_boundary  = left_ptr  + left_size;
    FOUR_BYTE_TYPE *right_boundary = right_ptr + right_size;

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

void
MSort_merge8(void *left_ptr_orig,  u32_t left_size,
            void *right_ptr_orig, u32_t right_size,
            void *dest_orig, MSort_compare_t compare, void *context) 
{
    EIGHT_BYTE_TYPE *left_ptr       = (EIGHT_BYTE_TYPE*)left_ptr_orig;
    EIGHT_BYTE_TYPE *right_ptr      = (EIGHT_BYTE_TYPE*)right_ptr_orig;
    EIGHT_BYTE_TYPE *dest           = (EIGHT_BYTE_TYPE*)dest_orig;
    EIGHT_BYTE_TYPE *left_boundary  = left_ptr  + left_size;
    EIGHT_BYTE_TYPE *right_boundary = right_ptr + right_size;

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

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

