#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/ANDScorer.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Util/ByteBuf.h"

ANDScorer*
ANDScorer_new(VArray *children, Similarity *sim) 
{
    ANDScorer *self = (ANDScorer*)VTable_Make_Obj(&ANDSCORER);
    return ANDScorer_init(self, children, sim);
}

ANDScorer*
ANDScorer_init(ANDScorer *self, VArray *children, Similarity *sim) 
{
    u32_t i;

    /* Init. */
    PolyMatcher_init((PolyMatcher*)self, children, sim);
    self->cap              = 10;
    self->first_time       = true;

    /* Assign. */
    self->more             = self->num_kids ? true : false;
    self->kids             = MALLOCATE(self->num_kids, Matcher*);
    for (i = 0; i < self->num_kids; i++) {
        Matcher *child = (Matcher*)VA_Fetch(children, i);
        self->kids[i] = child;
        if (!Matcher_Next(child)) self->more = false;
    }

    /* Derive. */
    self->matching_kids = self->num_kids;

    return self;
}

void
ANDScorer_destroy(ANDScorer *self) 
{
    FREEMEM(self->kids);
    SUPER_DESTROY(self, ANDSCORER);
}

i32_t
ANDScorer_next(ANDScorer *self)
{
    if (self->first_time) {
        return ANDScorer_Advance(self, 1);
    }
    if (self->more) {
        const i32_t target = Matcher_Get_Doc_ID(self->kids[0]) + 1;
        return ANDScorer_Advance(self, target);
    }
    else {
        return 0;
    }
}

i32_t
ANDScorer_advance(ANDScorer *self, i32_t target)
{
    Matcher **const kids = self->kids;
    const u32_t     num_kids   = self->num_kids;
    i32_t           highest    = 0;

    if (!self->more) return 0;

    /* First step: Advance first child and use its doc as a starting point. */
    if (self->first_time) {
        self->first_time = false;
    }
    else {
        highest = Matcher_Advance(kids[0], target);
        if (!highest) { 
            self->more = false;
            return 0;
        }
    }

    /* Second step: reconcile. */
    while(1) {
        u32_t i;
        bool_t agreement = true;

        /* Scoot all scorers up. */
        for (i = 0; i < num_kids; i++) {
            Matcher *const child = kids[i];
            i32_t candidate = Matcher_Get_Doc_ID(child);

            /* If this child is highest, others will need to catch up. */
            if (highest < candidate)
                highest = candidate;

            /* If least doc scorers can agree on exceeds target, raise bar. */
            if (target < highest)
                target = highest;

            /* Scoot this scorer up if not already at highest. */
            if (candidate < target) {
                /* This scorer is definitely the highest right now. */
                highest = Matcher_Advance(child, target);
                if (!highest) {
                    self->more = false;
                    return 0;
                }
            }
        }

        /* If scorers don't agree, send back through the loop. */
        for (i = 0; i < num_kids; i++) {
            Matcher *const child = kids[i];
            const i32_t candidate = Matcher_Get_Doc_ID(child);
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

    return highest;
}

i32_t
ANDScorer_get_doc_id(ANDScorer *self)
{
    return Matcher_Get_Doc_ID(self->kids[0]);
}

float
ANDScorer_score(ANDScorer *self)
{
    u32_t i;
    Matcher **const kids = self->kids;
    float score = 0.0f;

    for (i = 0; i < self->num_kids; i++) {
        score += Matcher_Score(kids[i]);
    }

    score *= self->coord_factors[ self->matching_kids ];

    return score;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

