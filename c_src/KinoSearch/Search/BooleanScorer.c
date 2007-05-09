#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_BOOLEANSCORER_VTABLE
#include "KinoSearch/Search/BooleanScorer.r"

#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Search/ANDScorer.r"
#include "KinoSearch/Search/ANDNOTScorer.r"
#include "KinoSearch/Search/ANDORScorer.r"
#include "KinoSearch/Search/ORScorer.r"

/* BooleanScorers award bonus points to documents which match multiple
 * subqueries.  This routine calculates the size of the bonuses. 
 */
static void
compute_coord_factors(BooleanScorer *scorer);

/* Trigger initialization, then proceed normally.  Called once only.
 */
static bool_t
next_first_time(BooleanScorer *self);
static bool_t
skip_to_first_time(BooleanScorer *self, u32_t target);

/* Choose an inner scorer based on what kinds of subscorers we've accumulated.
 */
static void 
init_inner_scorer(BooleanScorer *self);
static void
init_some_required(BooleanScorer *self);
static void
init_none_required(BooleanScorer *self);
static void
add_prohibited_scorers(BooleanScorer *self, Scorer *provisional_scorer);

BooleanScorer*
BoolScorer_new(Similarity *sim)
{
    CREATE(self, BooleanScorer, BOOLEANSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    self->sim              = sim;

    /* init */
    self->tally               = Tally_new();
    self->and_scorers         = VA_new(1);
    self->not_scorers         = VA_new(1);
    self->or_scorers          = VA_new(1);
    self->coord_factors       = NULL;
    self->max_coord           = 0;
    self->first_time          = true;

    /* prepare for delayed init on first call to Next or Skip_To */
    self->scorer              = (Scorer*)self;
    self->do_next             = (Scorer_next_t)next_first_time;
    self->do_skip_to          = (Scorer_skip_to_t)skip_to_first_time;

    return self;
}

void
BoolScorer_destroy(BooleanScorer *self) 
{
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->and_scorers);
    REFCOUNT_DEC(self->or_scorers);
    REFCOUNT_DEC(self->not_scorers);
    if (self->scorer != (Scorer*)self)
        REFCOUNT_DEC(self->scorer);
    free(self->coord_factors);
    free(self);
}

static ByteBuf must     = BB_LITERAL("MUST");
static ByteBuf must_not = BB_LITERAL("MUST_NOT");
static ByteBuf should   = BB_LITERAL("SHOULD");

void
BoolScorer_add_subscorer(BooleanScorer *self, Scorer *subscorer, 
                         const ByteBuf *occur)
{
    if (BB_Equals(occur, (Obj*)&must)) {
        VA_Push(self->and_scorers, (Obj*)subscorer); 
        self->max_coord++;
    }
    else if (BB_Equals(occur, (Obj*)&must_not)) {
        VA_Push(self->not_scorers, (Obj*)subscorer); 
    }
    else if (BB_Equals(occur, (Obj*)&should)) {
        VA_Push(self->or_scorers, (Obj*)subscorer);
        self->max_coord++;
    }
    else {
        CONFESS("Unrecognized value for 'occur': '%s'", occur->ptr);
    }
}

static void
compute_coord_factors(BooleanScorer *self) 
{
    u32_t  i;
    Similarity *const sim = self->sim;
    const u32_t max_coord = self->max_coord;
    float *coord_factors = MALLOCATE((max_coord + 1), float);

    self->coord_factors = coord_factors;
    for (i = 0; i <= max_coord; i++) {
        *coord_factors++ = Sim_Coord(sim, i, max_coord);
    }
}

static bool_t
next_first_time(BooleanScorer *self)
{
    compute_coord_factors(self);
    init_inner_scorer(self);
    return self->do_next(self->scorer);
}

static bool_t
skip_to_first_time(BooleanScorer *self, u32_t target)
{
    compute_coord_factors(self);
    init_inner_scorer(self);
    return self->do_skip_to(self->scorer, target);
}

bool_t
BoolScorer_next(BooleanScorer *self)
{
    return self->do_next(self->scorer);
}

bool_t
BoolScorer_skip_to(BooleanScorer *self, u32_t target)
{
    return self->do_skip_to(self->scorer, target);
}

static bool_t
next_is_false(BooleanScorer *self)
{
    return false;
}

static bool_t
skip_to_is_false(BooleanScorer *self, u32_t target)
{
    UNUSED_VAR(target);
    return false;
}

static void
init_inner_scorer(BooleanScorer *self)
{
    /* start the branching */
    if (self->and_scorers->size > 0) {
        init_some_required(self);
    }
    else if (self->or_scorers->size > 0) {
        init_none_required(self);
    }
    else {
        /* all prohibited */
        self->scorer     = NULL;
        self->do_next    = (Scorer_next_t)next_is_false;
        self->do_skip_to = (Scorer_skip_to_t)skip_to_is_false;
    }
}

static void
init_none_required(BooleanScorer *self)
{
    Scorer *provisional_scorer;

    if (self->or_scorers->size == 1) {
        provisional_scorer = (Scorer*)VA_Fetch(self->or_scorers, 0);
        REFCOUNT_INC(provisional_scorer);
    }
    else {
        provisional_scorer 
            = (Scorer*)ORScorer_new(self->sim, self->or_scorers);
    }
    
    add_prohibited_scorers(self, provisional_scorer);
}

static void
init_some_required(BooleanScorer *self)
{
    Scorer *provisional_scorer;
    Scorer *or_scorer = NULL;

    if (self->and_scorers->size == 1) {
        provisional_scorer = (Scorer*)VA_Fetch(self->and_scorers, 0);
        REFCOUNT_INC(provisional_scorer);
    }
    else {
        u32_t i;
        provisional_scorer = (Scorer*)ANDScorer_new(self->sim);
        for (i = 0; i < self->and_scorers->size; i++) {
            Scorer *subscorer = (Scorer*)VA_Fetch(self->and_scorers, i); 
            ANDScorer_add_subscorer((ANDScorer*)provisional_scorer, 
                subscorer);
        }
    }

    if (self->or_scorers->size == 1) {
        or_scorer = (Scorer*)VA_Fetch(self->or_scorers, 0);
        REFCOUNT_INC(or_scorer);
    }
    else if (self->or_scorers->size > 1) {
        or_scorer = (Scorer*)ORScorer_new(self->sim, self->or_scorers);
    }

    if (or_scorer != NULL) {
        ANDORScorer *temp = ANDORScorer_new(self->sim, provisional_scorer, 
            or_scorer);
        REFCOUNT_DEC(provisional_scorer);
        REFCOUNT_DEC(or_scorer);
        provisional_scorer = (Scorer*)temp;
    }

    add_prohibited_scorers(self, provisional_scorer);
}

static void
add_prohibited_scorers(BooleanScorer *self, Scorer *provisional_scorer)
{
    Scorer *not_scorer = NULL;

    /* group not scorers together if necessary */
    if (self->not_scorers->size == 1) {
        not_scorer = (Scorer*)VA_Fetch(self->not_scorers, 0); 
        REFCOUNT_INC(not_scorer);
    }
    else if (self->not_scorers->size > 1) {
        not_scorer = (Scorer*)ORScorer_new(self->sim, self->not_scorers);
    }

    if (not_scorer != NULL) {
        ANDNOTScorer *temp = ANDNOTScorer_new(self->sim, provisional_scorer, 
            not_scorer);
        REFCOUNT_DEC(provisional_scorer);
        REFCOUNT_DEC(not_scorer);
        provisional_scorer = (Scorer*)temp;
    }

    /* save one extra deref */
    self->scorer     = provisional_scorer;
    self->do_next    = provisional_scorer->_->next;
    self->do_skip_to = provisional_scorer->_->skip_to;
}

u32_t
BoolScorer_doc(BooleanScorer *self)
{
    return Scorer_Doc(self->scorer);
}

Tally*
BoolScorer_tally(BooleanScorer *self)
{
    Tally *const tally        = self->tally;
    Tally *const raw_tally    = Scorer_Tally(self->scorer);
    const u32_t  num_matchers = raw_tally->num_matchers;

    /* transfer score; factor in coord */
    tally->score = raw_tally->score;
    if (num_matchers > self->max_coord)
        CONFESS("Too many matchers: %u > %u", num_matchers, self->max_coord);
    tally->score *= self->coord_factors[ raw_tally->num_matchers ];
    /* Note: we retain num_matchers of 1 in our final tally, so that if this
     * BooleanScorer is a subscorer of another, the coord doesn't feed back.
     */

    return tally;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

