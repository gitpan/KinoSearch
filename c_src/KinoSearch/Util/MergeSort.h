/* KinoSearch/Util/MergeSort.h - a specialized merge sort
 *
 * KinoSearch's MergeSort algorithm allows for unusual access to its
 * internals, enabling specialized functions to jump in and only execute part
 * of the sort.
 */

#ifndef H_KINO_MERGESORT
#define H_KINO_MERGESORT 1

#include "charmony.h"
struct kino_ByteBuf;

/* Perform a mergesort.  In addition to providing a contiguous array of
 * elements to be sorted and their count, the caller must also provide a
 * scratch buffer with room for at least as many elements as are to be sorted.
 * 
 * This is a wrapper function which calculates the necessary arguments and
 * immediately dispatches to MSort_do_sort.
 */
void
kino_MSort_mergesort(struct kino_ByteBuf **elems, 
                     struct kino_ByteBuf **scratch, 
                     kino_u32_t num_elems);

/* Standard mergesort function.
 */
void
kino_MSort_do_sort(struct kino_ByteBuf **elems, 
                   struct kino_ByteBuf **scratch, 
                   kino_u32_t left, kino_u32_t right);

/* Merge two source arrays together using the classic mergesort merge
 * algorithm, storing the result in [dest].
 * 
 * Most merge functions operate on a single contiguous array and copy the
 * merged results results back into the source array before returning.  This
 * one differs in that it is capable of operating on two discontiguous source
 * arrays.  It leaves the responsibility for copying the results back into the
 * source array to the caller.
 * 
 * KinoSearch's external sorting module takes advantage of this when it is
 * reading back pre-sorted runs from disk and merging the streams into a
 * consolidated buffer.
 */
void
kino_MSort_merge(struct kino_ByteBuf **left_ptr,  kino_u32_t left_size,
                 struct kino_ByteBuf **right_ptr, kino_u32_t right_size,
                 struct kino_ByteBuf **dest);


#ifdef KINO_USE_SHORT_NAMES
# define MSort_mergesort            kino_MSort_mergesort
# define MSort_do_sort              kino_MSort_do_sort
# define MSort_merge                kino_MSort_merge
#endif

#endif /* H_KINO_MERGESORT */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

