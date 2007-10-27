#ifndef H_KINO_BBSORTEXRUN
#define H_KINO_BBSORTEXRUN 1

#include "KinoSearch/Util/SortExRun.r"

struct kino_InStream;
struct kino_OutStream;

typedef struct kino_BBSortExRun kino_BBSortExRun;
typedef struct KINO_BBSORTEXRUN_VTABLE KINO_BBSORTEXRUN_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Util::BBSortExRun", "BBSortExRun",
    "KinoSearch::Util::SortExRun");

struct kino_BBSortExRun {
    KINO_BBSORTEXRUN_VTABLE *_;
    KINO_SORTEXRUN_MEMBER_VARS;
    struct kino_InStream *instream;
    chy_u32_t             mem_thresh;
    chy_u64_t             start;
    chy_u64_t             end;
};

/* Constructor. 
 */
kino_BBSortExRun*
kino_BBSortExRun_new(kino_Obj** elems, chy_u32_t num_elems);

/* Preapare to start reading back.  Must be called before Refill.
 */
void
kino_BBSortExRun_flip(kino_BBSortExRun *self, struct kino_InStream *instream,
                      chy_u32_t mem_thresh);
KINO_METHOD("Kino_BBSortExRun_Flip");

void
kino_BBSortExRun_flush(kino_BBSortExRun *self, 
                       struct kino_OutStream *outstream);
KINO_METHOD("Kino_BBSortExRun_Flush");

chy_u32_t
kino_BBSortExRun_refill(kino_BBSortExRun *self);
KINO_METHOD("Kino_BBSortExRun_Refill");

void
kino_BBSortExRun_destroy(kino_BBSortExRun *self);
KINO_METHOD("Kino_BBSortExRun_Destroy");

KINO_END_CLASS

#endif /* H_KINO_BBSORTEXRUN */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

