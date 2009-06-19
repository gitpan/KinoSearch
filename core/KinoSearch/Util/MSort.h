/* KinoSearch/Util/MSort.h - Specialized merge sort.
 *
 * Mergesort algorithm which allows access to its internals, enabling
 * specialized functions to jump in and only execute part of the sort.
 */

#ifndef H_KINO_MSORT
#define H_KINO_MSORT 1

#include "charmony.h"

typedef int 
(*kino_MSort_compare_t)(void *context, const void *va, const void *vb);

/* Perform a mergesort.  In addition to providing a contiguous array of
 * elements to be sorted and their count, the caller must also provide a
 * scratch buffer with room for at least as many elements as are to be sorted.
 */
void
kino_MSort_mergesort(void *elems, void *scratch, 
                     chy_u32_t num_elems, chy_u32_t bytes_per_elem,
                     kino_MSort_compare_t compare, void *context);

/* Standard mergesort function.
 */
void
kino_MSort_do_sort(void *elems, void *scratch, 
                   chy_u32_t left, chy_u32_t right,
                   kino_MSort_compare_t compare, void *context);

/* Merge two source arrays together using the classic mergesort merge
 * algorithm, storing the result in [dest].
 * 
 * Most merge functions operate on a single contiguous array and copy the
 * merged results results back into the source array before returning.  These
 * two differ in that it is possible to operate on two discontiguous source
 * arrays.  Copying the results back into the source array is the
 * responsibility of the caller.
 * 
 * KinoSearch's external sort takes advantage of this when it is reading back
 * pre-sorted runs from disk and merging the streams into a consolidated
 * buffer.
 * 
 * merge4 merges elements which are 4 bytes in size; merge8 merges 8-byte
 * elements.
 */
void
kino_MSort_merge4(void *left_ptr,  chy_u32_t left_num_elems,
                  void *right_ptr, chy_u32_t right_num_elems,
                  void *dest, kino_MSort_compare_t compare, void *context);
void
kino_MSort_merge8(void *left_ptr,  chy_u32_t left_num_elems,
                  void *right_ptr, chy_u32_t right_num_elems,
                  void *dest, kino_MSort_compare_t compare, void *context);


#ifdef KINO_USE_SHORT_NAMES
  #define MSort_compare_t            kino_MSort_compare_t
  #define MSort_mergesort            kino_MSort_mergesort
  #define MSort_merge4               kino_MSort_merge4
  #define MSort_merge8               kino_MSort_merge8
#endif

#endif /* H_KINO_MSORT */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

