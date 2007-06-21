#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_ANDNOTSCORER_VTABLE
#include "KinoSearch/Search/ANDNOTScorer.r"

#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"

/* A version of Skip_To without the checks.  When called...
 *    - and_scorer is not NULL
 *    - not_scorer is not NULL
 *    - and_scorer has been advanced to a valid doc
 */
static bool_t
to_non_excluded(ANDNOTScorer *self);

ANDNOTScorer*
ANDNOTScorer_new(Similarity *sim, Scorer *and_scorer, Scorer *not_scorer) 
{
    CREATE(self, ANDNOTScorer, ANDNOTSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    REFCOUNT_INC(and_scorer);
    REFCOUNT_INC(not_scorer);
    self->sim              = sim;
    self->and_scorer       = and_scorer;
    self->not_scorer       = not_scorer;

    /* init */
    self->first_time       = true;

    return self;
}

void
ANDNOTScorer_destroy(ANDNOTScorer *self) 
{
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->and_scorer);
    REFCOUNT_DEC(self->not_scorer);

    free(self);
}

bool_t
ANDNOTScorer_next(ANDNOTScorer *self)
{
    if (self->first_time) {
        return Scorer_Skip_To(self, 0);
    }
    else if (self->and_scorer != NULL) {
        const u32_t target = Scorer_Doc(self->and_scorer) + 1;
        return Scorer_Skip_To(self, target);
    }
    else {
        return false;
    }
}

bool_t
ANDNOTScorer_skip_to(ANDNOTScorer *self, u32_t target)
{
    if (self->first_time) {
        self->first_time = false;

        /* see if the negated scorer has any docs at all */
        if ( !Scorer_Skip_To(self->not_scorer, 0) ) {
            REFCOUNT_DEC(self->not_scorer);
            self->not_scorer = NULL;
        }
    }

    /* if the required scorer is empty, we're done */
    if (self->and_scorer == NULL)
        return false;

    /* if no more exclusions, return anything from the required scorer */
    if (self->not_scorer == NULL)
        return Scorer_Next(self->and_scorer);

    if ( Scorer_Next(self->and_scorer) ) {
        return to_non_excluded(self);
    }
    else {
        /* bail if required score exausted */
        REFCOUNT_DEC(self->and_scorer);
        self->and_scorer = NULL;
        return false;
    }
}

static bool_t
to_non_excluded(ANDNOTScorer *self)
{
    Scorer *const and_scorer = self->and_scorer;
    Scorer *const not_scorer = self->not_scorer;
    u32_t required_doc       = Scorer_Doc(and_scorer);
    u32_t negated_doc        = Scorer_Doc(not_scorer);

    while (1) {
        if (required_doc < negated_doc) {
            /* success -- required doc not negated */
            return true;
        }
        else if (negated_doc < required_doc) {
            if ( Scorer_Skip_To(not_scorer, required_doc) ) {
                negated_doc = Scorer_Doc(not_scorer);
                if (required_doc < negated_doc) {
                    /* success -- required doc not negated */
                    return true;
                }
            }
            else {
                /* success -- no more exclusions */
                REFCOUNT_DEC(not_scorer);
                self->not_scorer = NULL;
                return true;
            }
        }

        /* current required doc is negated, so advance */
        if ( Scorer_Next(and_scorer) ) 
            required_doc = Scorer_Doc(and_scorer);
        else 
            break;
    }

    /* if we've made it this far, we're out of required docs */
    REFCOUNT_DEC(self->and_scorer);
    self->and_scorer = NULL;
    return false;
}

u32_t
ANDNOTScorer_doc(ANDNOTScorer *self)
{
    return Scorer_Doc(self->and_scorer);
}

Tally*
ANDNOTScorer_tally(ANDNOTScorer *self)
{
    return Scorer_Tally(self->and_scorer);
}

u32_t
ANDNOTScorer_max_matchers(ANDNOTScorer *self)
{
    return Scorer_Max_Matchers(self->and_scorer);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

