#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_ANDSCORER_VTABLE
#include "KinoSearch/Search/ANDScorer.r"

#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"

/* Perform some initialization stuff we can't know until all subscorers have
 * been added.  Return false if we'll never match anything with this scorer.
 */
static bool_t 
delayed_init(ANDScorer *self, u32_t target);

/* Mark this scorer as invalid/finished.
 */
static bool_t
invalidate(ANDScorer *self);

/* Return the highest value for doc() from an array of Scorers.
 */
static u32_t
highest_doc(Scorer **subscorers, u32_t num_subs);

ANDScorer*
ANDScorer_new(Similarity *sim) 
{
    CREATE(self, ANDScorer, ANDSCORER);

    /* assign */
    self->sim = sim;
    REFCOUNT_INC(sim);

    /* init */
    self->tally            = Tally_new();
    self->cap              = 10;
    self->subscorers       = MALLOCATE(10, Scorer*);
    self->num_subs         = 0;
    self->raw_prox_bb      = BB_new(0);
    self->first_time       = true;
    self->more             = true;

    return self;
}

void
ANDScorer_destroy(ANDScorer *self) 
{
    u32_t i;
    REFCOUNT_DEC(self->raw_prox_bb);
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->tally);

    for (i = 0; i < self->num_subs; i++) {
        REFCOUNT_DEC(self->subscorers[i]);
    }
    free(self->subscorers);

    free(self);
}

void
ANDScorer_add_subscorer(ANDScorer *self, Scorer *subscorer)
{
    if (!self->first_time)
        CONFESS("Can't add scorers after starting iteration");

    if (self->num_subs == self->cap) {
        self->cap += 100;
        self->subscorers = REALLOCATE(self->subscorers, self->cap, Scorer*);
    }
    REFCOUNT_INC(subscorer);
    self->subscorers[ self->num_subs++ ] = subscorer;

    /* add to the matcher count; don't bother with subclauses */
    self->tally->num_matchers += 1;
}

static bool_t 
delayed_init(ANDScorer *self, u32_t target)
{
    u32_t i;

    /* once is enough */
    self->first_time = false;

    /* no scorers, no matches! */
    if (!self->num_subs)
        return invalidate(self);

    /* set fixed value for num_matchers */
    self->tally->num_matchers = self->num_subs;

    /* calculate coord multiplier */
    self->coord = Sim_Coord(self->sim, self->num_subs, self->num_subs);

    /* advance all scorers */
    for (i = 0; i < self->num_subs; i++) {
        if (!Scorer_Skip_To(self->subscorers[i], target))
            return invalidate(self);
    }

    return true;
}

bool_t
ANDScorer_next(ANDScorer *self)
{
    if (self->first_time) {
        return Scorer_Skip_To(self, 0);
    }
    else if (self->more) {
        const u32_t target = Scorer_Doc(self->subscorers[0]) + 1;
        return Scorer_Skip_To(self, target);
    }
    else {
        return false;
    }
}

static bool_t
invalidate(ANDScorer *self)
{
    self->more = false;
    return false;
}

static u32_t
highest_doc(Scorer **subscorers, u32_t num_subs)
{
    u32_t highest = 0;
    u32_t i;

    for (i = 0; i < num_subs; i++) {
        u32_t candidate = Scorer_Doc(subscorers[i]); 
        if (candidate > highest)
            highest = candidate;
    }

    return highest;
}

bool_t
ANDScorer_skip_to(ANDScorer *self, u32_t target)
{
    Scorer **const subscorers = self->subscorers;
    const u32_t    num_subs   = self->num_subs;
    u32_t          highest    = 0;

    /* first step: advance */
    if (self->first_time) {
        /* scoot ALL subscorers and find the least doc they might agree on */
        if ( !delayed_init(self, target) )
            return invalidate(self);
        highest = highest_doc(subscorers, num_subs);
    }
    else {
        /* advance first subscorer and use it's doc as a starting point */
        if ( !Scorer_Skip_To(subscorers[0], target) )
            return invalidate(self);
        highest = Scorer_Doc(subscorers[0]);
    }

    /* second step: reconcile */
    while(1) {
        u32_t i;
        bool_t agreement = true;

        /* scoot all scorers up */
        for (i = 0; i < num_subs; i++) {
            Scorer *const subscorer = subscorers[i];
            u32_t candidate = Scorer_Doc(subscorer);

            /* if this subscorer is highest, others will need to catch up */
            if (highest < candidate)
                highest = candidate;

            /* if least doc scorers can agree on exceeds target, raise bar */
            if (target < highest)
                target = highest;

            /* scoot this scorer up if not already at highest */
            if (candidate < target) {
                if ( !Scorer_Skip_To(subscorer, target) )
                    return invalidate(self);

                /* this scorer is definitely the highest right now */
                highest = Scorer_Doc(subscorer);
            }
        }

        /* if scorers don't agree, send back through the loop */
        for (i = 0; i < num_subs; i++) {
            Scorer *const subscorer = subscorers[i];
            const u32_t candidate = Scorer_Doc(subscorer);
            if (candidate != highest) {
                agreement = false;
                break;
            }
        }

        if (!agreement)
            continue;
        if (highest >= target)
            break;
    } 

    return true;
}

u32_t
ANDScorer_doc(ANDScorer *self)
{
    return Scorer_Doc(self->subscorers[0]);
}

Tally*
ANDScorer_tally(ANDScorer *self)
{
    u32_t i;
    Scorer **const subscorers = self->subscorers;
    Tally *const   tally      = self->tally;

    tally->score = 0.0f;
    for (i = 0; i < self->num_subs; i++) {
        Tally *subtally = Scorer_Tally(subscorers[i]);
        tally->score        += subtally->score;
    }

    tally->score *= self->coord;

    return tally;
}

u32_t
ANDScorer_max_matchers(ANDScorer *self)
{
    return self->num_subs;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

