#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_ANDORSCORER_VTABLE
#include "KinoSearch/Search/ANDORScorer.r"

#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"

ANDORScorer*
ANDORScorer_new(Similarity *sim, Scorer *and_scorer, Scorer *or_scorer) 
{
    CREATE(self, ANDORScorer, ANDORSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    REFCOUNT_INC(and_scorer);
    REFCOUNT_INC(or_scorer);
    self->sim              = sim;
    self->and_scorer       = and_scorer;
    self->or_scorer        = or_scorer;

    /* init */
    self->or_scorer_first_time = true;
    self->tally            = Tally_new();

    return self;
}

void
ANDORScorer_destroy(ANDORScorer *self) 
{
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->and_scorer);
    REFCOUNT_DEC(self->or_scorer);

    free(self);
}

bool_t
ANDORScorer_next(ANDORScorer *self)
{
    return Scorer_Next(self->and_scorer);
}

bool_t
ANDORScorer_skip_to(ANDORScorer *self, u32_t target)
{
    return Scorer_Skip_To(self->and_scorer, target);
}

u32_t
ANDORScorer_doc(ANDORScorer *self)
{
    return Scorer_Doc(self->and_scorer);
}

Tally*
ANDORScorer_tally(ANDORScorer *self)
{
    u32_t const current_doc = Scorer_Doc(self->and_scorer);

    if (self->or_scorer_first_time) {
        self->or_scorer_first_time = false;
        if ( !Scorer_Skip_To(self->or_scorer, current_doc) ) {
            REFCOUNT_DEC(self->or_scorer);
            self->or_scorer = NULL;
        }
    }

    if (self->or_scorer == NULL) {
        return Scorer_Tally(self->and_scorer);
    }
    else {
        u32_t or_scorer_doc = Scorer_Doc(self->or_scorer);

        if (or_scorer_doc < current_doc) {
            if ( !Scorer_Skip_To(self->or_scorer, current_doc) ) {
                REFCOUNT_DEC(self->or_scorer);
                self->or_scorer = NULL;
                return Scorer_Tally(self->and_scorer);
            }
            else {
                or_scorer_doc = Scorer_Doc(self->or_scorer);
            }
        }

        if (or_scorer_doc == current_doc) {
            Tally *const tally       = self->tally;
            Tally *const and_tally   = Scorer_Tally(self->and_scorer);
            Tally *const or_tally    = Scorer_Tally(self->or_scorer);

            tally->score = and_tally->score + or_tally->score;
            tally->num_matchers 
                = and_tally->num_matchers + or_tally->num_matchers;

            return tally;
        }
        else {
            return Scorer_Tally(self->and_scorer);
        }
    }
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

