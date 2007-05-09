#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCORER_VTABLE
#include "KinoSearch/Search/Scorer.r"

#include "KinoSearch/Search/HitCollector.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Int.r"


Tally*
Scorer_tally(Scorer *self) 
{
    ABSTRACT_DEATH(self, "Tally");
    UNREACHABLE_RETURN(Tally*);
}

bool_t
Scorer_next(Scorer *self) 
{
    ABSTRACT_DEATH(self, "Next");
    UNREACHABLE_RETURN(bool_t);
}

u32_t
Scorer_doc(Scorer *self) 
{
    ABSTRACT_DEATH(self, "Doc");
    UNREACHABLE_RETURN(u32_t);
}

bool_t
Scorer_skip_to(Scorer *self, u32_t target) 
{
    do {
        if ( !Scorer_Next(self) )
            return false;
    } while ( target > Scorer_Doc(self) );

    return true;
}


void
Scorer_collect(Scorer *self, HitCollector *hc, u32_t start, u32_t end, 
               u32_t hits_per_seg, VArray *seg_starts)
{
    u32_t              seg_num          = 0;
    u32_t              doc_num_thresh   = 0;
    u32_t              hits_this_seg    = 0;
    u32_t              hits_thresh      = hits_per_seg;

    /* get to first doc */
    if ( !Scorer_Skip_To(self, start) )
        return;

    /* execute scoring loop */
    do {
        u32_t doc_num = Scorer_Doc(self);
        Tally *tally;

        if (hits_this_seg >= hits_thresh || doc_num >= doc_num_thresh) {
            if (doc_num >= end) {
                /* bail out of loop if we've hit the user-spec'd end */
                return;
            }
            else if (seg_starts == NULL || seg_starts->size == 0) {
                /* must supply seg_starts to enable pruning */
                hits_thresh    = U32_MAX;
                doc_num_thresh = end;
            }
            else if (seg_num == seg_starts->size) {
                /* we've finished the last segment */
                return;
            }
            else {
                /* get start of upcoming segment */
                Int *this_start = (Int*)VA_Fetch(seg_starts, seg_num);
                Int *next_start = (Int*)VA_Fetch(seg_starts, seg_num + 1);
                u32_t this_seg_start = this_start->value;
                seg_num++;

                /* skip docs as appropriate if we're pruning */
                if (doc_num < this_seg_start) {
                    if ( Scorer_Skip_To(self, this_seg_start) )
                        doc_num = Scorer_Doc(self);
                    else
                        return;
                }

                /* set the last doc_num we'll score this upcoming segment */
                doc_num_thresh = next_start == NULL
                    ? end  /* last segment */
                    : next_start->value;
            }

            /* start over counting hits for the new segment */
            hits_this_seg = 0;
        }

        /* this doc is in range, so collect it */
        tally = Scorer_Tally(self);
        hc->collect(hc, doc_num, tally->score);
        hits_this_seg++;
    } while (Scorer_Next(self));
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

