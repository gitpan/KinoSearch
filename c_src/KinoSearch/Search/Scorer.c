#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCORER_VTABLE
#include "KinoSearch/Search/Scorer.r"

#include "KinoSearch/Search/HitCollector.r"
#include "KinoSearch/Util/Int.r"


float
Scorer_score(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Score must be defined in a subclass");
    UNREACHABLE_RETURN(float);
}

bool_t
Scorer_next(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Next must be defined in a subclass");
    UNREACHABLE_RETURN(bool_t);
}

u32_t
Scorer_doc(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Doc must be defined in a subclass");
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
Scorer_score_batch(Scorer *self, HitCollector *hc, u32_t start, u32_t end, 
                   u32_t prune_factor, VArray *seg_starts)
{
    u32_t seg_num         = 0;
    u32_t thresh          = 0;

    /* get to first doc */
    if ( !Kino_Scorer_Skip_To(self, start) )
        return;

    /* execute scoring loop */
    do {
        u32_t doc_num = Kino_Scorer_Doc(self);
        if (doc_num >= thresh) {
            /* bail out of loop if we've hit the user-spec'd end */
            if (doc_num >= end) {
                return;
            }
            else if (seg_starts == NULL || seg_starts->size == 0) {
                end = prune_factor < end ? prune_factor : end;
                thresh = end;
            }
            else {
                /* get start of next segment */
                Int *this_start_int = (Int*)VA_Fetch(seg_starts, seg_num);
                Int *next_start_int = (Int*)VA_Fetch(seg_starts, seg_num + 1);
                u32_t this_seg_start = 0;
                seg_num++;

                /* skip some docs if we need to */
                if (this_start_int == NULL) {
                    return;
                }
                else {
                    this_seg_start = this_start_int->value;
                    if (doc_num < this_seg_start) {
                        if ( Kino_Scorer_Skip_To(self, this_seg_start) )
                            doc_num = Scorer_Doc(self);
                        else
                            return;
                    }
                }

                if (next_start_int == NULL) {
                    thresh = this_seg_start + prune_factor;
                }
                else {
                    const u32_t next_seg_start = next_start_int->value;
                    thresh = this_seg_start + prune_factor < next_seg_start 
                        ? this_seg_start + prune_factor
                        : next_seg_start;
                    if (thresh > end)
                        thresh = end;
                }
            }
        }

        /* this doc is in range, so collect it */
        hc->collect( hc, doc_num, Kino_Scorer_Score(self) );
    } while (Kino_Scorer_Next(self));
}
/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

