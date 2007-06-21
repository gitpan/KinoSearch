#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_PHRASESCORER_VTABLE
#include "KinoSearch/Search/PhraseScorer.r"

#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Posting/ScorePosting.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/ScoreProx.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Native.r"
#include "KinoSearch/Util/Int.r"

/* Mark this scorer as invalid/finished.
 */
static bool_t
invalidate(PhraseScorer *self);

/* Return the highest value for doc() from an array of PostingList objects.
 */
static u32_t
highest_doc(PostingList **plists, u32_t num_elements);

/* Build up the array of positions which match this query within the current
 * doc.
 */
static void
build_prox(PhraseScorer *self);

PhraseScorer*
PhraseScorer_new(Similarity *sim, VArray *plists, VArray *phrase_offsets,
                 void *weight, float weight_val, u32_t slop)
{
    u32_t i;
    CREATE(self, PhraseScorer, PHRASESCORER);

    /* init */
    self->tally            = Tally_new();
    self->sprox            = ScoreProx_new();
    Tally_Add_SProx(self->tally, self->sprox);
    self->anchor_set       = BB_new(0);
    self->raw_prox_bb      = BB_new(0);
    self->phrase_freq      = 0.0;
    self->phrase_boost     = 0.0;
    self->first_time       = true;
    self->more             = true;

    /* extract posting lists and phrase offsets for quick access */
    self->num_elements   = plists->size;
    self->plists         = MALLOCATE(self->num_elements, PostingList*);
    self->phrase_offsets = MALLOCATE(self->num_elements, u32_t);
    for (i = 0; i < self->num_elements; i++) {
        PostingList *const plist = (PostingList*)VA_Fetch(plists, i);
        Int *const offset = (Int*)VA_Fetch(phrase_offsets, i);
        if (plist == NULL || offset == NULL)
            CONFESS("Missing element %u", i);
        REFCOUNT_INC(plist);
        self->plists[i] = plist;
        self->phrase_offsets[i] = offset->value;
    }

    /* assign */
    REFCOUNT_INC(sim);
    self->sim             = sim;
    self->weight_value    = weight_val;
    self->weight          = Native_new(weight);
    self->slop            = slop;

    return self;
}

void
PhraseScorer_destroy(PhraseScorer *self) 
{
    size_t i;
    PostingList **plists = self->plists;

    for (i = 0; i < self->num_elements; i++) {
        REFCOUNT_DEC(plists[i]);
    }
    free(self->plists);
    free(self->phrase_offsets);

    REFCOUNT_DEC(self->sprox);
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->raw_prox_bb);
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->anchor_set);
    REFCOUNT_DEC(self->weight);

    free(self);
}

static bool_t
invalidate(PhraseScorer *self)
{
    self->more = false;
    return false;
}

static u32_t
highest_doc(PostingList **plists, u32_t num_elements)
{
    u32_t highest = 0;

    while(num_elements--) {
        u32_t candidate = PList_Get_Doc_Num(*plists); 
        if (candidate > highest)
            highest = candidate;
        plists++;
    }

    return highest;
}

bool_t
PhraseScorer_next(PhraseScorer *self)
{
    if (self->first_time) {
        return Scorer_Skip_To(self, 0);
    }
    else if (self->more) {
        const u32_t target = PList_Get_Doc_Num(self->plists[0]) + 1;
        return Scorer_Skip_To(self, target);
    }
    else {
        return false;
    }
}

bool_t
PhraseScorer_skip_to(PhraseScorer *self, u32_t target) 
{
    PostingList **const plists       = self->plists;
    const u32_t         num_elements = self->num_elements;
    u32_t               highest      = 0;

    self->phrase_freq = 0.0;
    self->doc_num    = DOC_NUM_SENTINEL; 

    if (self->first_time) {
        u32_t i;
        self->first_time = false;
        /* advance all posting lists */
        for (i = 0; i < num_elements; i++) {
            if ( !PList_Next(plists[i]) )
                return invalidate(self);
        }
        highest = highest_doc(plists, num_elements);
    }
    else {
        /* seed the search, advancing only one posting list */
        if ( !PList_Next(plists[0]) )
            return false;
        highest = PList_Get_Doc_Num(plists[0]);
    }

    /* find a doc which contains all the terms */
    while (1) {
        u32_t i;
        bool_t agreement = true;

        /* scoot all posting lists up */
        for (i = 0; i < num_elements; i++) {
            PostingList *const plist = plists[i];
            u32_t candidate = PList_Get_Doc_Num(plist);

            /* maybe raise the bar */
            if (highest < candidate)
                highest = candidate;
            if (target < highest)
                target = highest;

            /* scoot this posting list up */
            if (candidate < target) {
                if ( !PList_Skip_To(plist, target) )
                    return invalidate(self);
                /* if somebody's raised the bar, don't wait till next loop */
                highest = PList_Get_Doc_Num(plist);
            }
        }

        /* if posting lists don't agree, send back through the loop */
        for (i = 0; i < num_elements; i++) {
            PostingList *const plist = plists[i];
            const u32_t candidate    = PList_Get_Doc_Num(plist);
            if (candidate != highest)
                agreement = false;
        }

        if (agreement && highest >= target) {
            self->phrase_freq = PhraseScorer_Calc_Phrase_Freq(self);
            if (self->phrase_freq == 0.0) {
                target += 1;
            }
            else {
                /* success! */
                self->doc_num  = highest;
                build_prox(self);
                return true;
            }
        }
    }
}

static void
build_prox(PhraseScorer *self)
{
    ScoreProx *const sprox    = self->sprox;
    ByteBuf *const anchor_set = self->anchor_set;
    u32_t *anchors            = (u32_t*)anchor_set->ptr;
    u32_t *anchors_end        = (u32_t*)BBEND(anchor_set);
    u32_t *dest;

    /* set num_prox */
    sprox->num_prox = (anchor_set->len / sizeof(u32_t)) * self->num_elements;
    
    /* allocate space for the prox as needed and get a pointer to write to */
    BB_GROW(self->raw_prox_bb, sprox->num_prox * sizeof(u32_t));
    self->raw_prox_bb->len = sprox->num_prox * sizeof(u32_t);
    dest = (u32_t*)self->raw_prox_bb->ptr;
    sprox->prox = dest;

    /* create one group for each anchor */
    for (  ; anchors < anchors_end; anchors++) {
        u32_t i;
        /* create 1 pos for each element */
        for (i = 0; i < self->num_elements; i++) {
            *dest++ = *anchors + i;
        }
    }
}

float
PhraseScorer_calc_phrase_freq(PhraseScorer *self) 
{
    PostingList **const plists   = self->plists;
    ByteBuf *const anchor_set    = self->anchor_set;
    u32_t  phrase_offset         = self->phrase_offsets[0];
    u32_t  i;
    u32_t *anchors, *anchors_start, *anchors_end;
    ScorePosting *first_posting;

    /* create an anchor set */
    first_posting = (ScorePosting*)PList_Get_Posting(plists[0]);
    BB_Copy_Str(anchor_set, (char*)first_posting->prox, 
        first_posting->freq * sizeof(u32_t));
    anchors_start = (u32_t*)anchor_set->ptr;
    anchors       = anchors_start;
    anchors_end   = (u32_t*)BBEND(anchor_set);
    while(anchors < anchors_end) {
        *anchors++ -= phrase_offset;
    }

    /* match the positions of other terms against the anchor set */
    for (i = 1; i < self->num_elements; i++) {
        ScorePosting *posting  = (ScorePosting*)PList_Get_Posting(plists[i]);
        u32_t *candidates      = posting->prox;
        u32_t *candidates_end  = posting->prox + posting->freq;

        u32_t *new_anchors = anchors_start;
        anchors     = anchors_start;
        anchors_end = (u32_t*)BBEND(anchor_set);

        phrase_offset = self->phrase_offsets[i];

        while (anchors < anchors_end) {
            u32_t target = *candidates - phrase_offset;
            while (anchors < anchors_end && *anchors < target) {
                anchors++;
            }
            if (anchors == anchors_end)
                break;

            target = *anchors + phrase_offset;
            while (candidates < candidates_end && *candidates < target) {
                candidates++;
            }

            if (candidates == candidates_end) {
                break;
            }
            else if (*candidates == target) {
                /* the anchor has made it through another elimination round */
                *new_anchors = *anchors;
                new_anchors++;
            }
            anchors++;
        }

        /* winnow down the size of the anchor set */
        anchor_set->len = (char*)new_anchors - (char*)anchors_start;
    }

    /* the number of anchors left is the phrase freq */
    return (float) anchor_set->len / sizeof(u32_t);
}

u32_t
PhraseScorer_doc(PhraseScorer *self) 
{
    return self->doc_num;
}

Tally*
PhraseScorer_tally(PhraseScorer *self) 
{
    ScorePosting *posting = (ScorePosting*)PList_Get_Posting(self->plists[0]);
    self->tally->score = Sim_TF(self->sim, self->phrase_freq) 
         * self->weight_value * posting->impact;
    return self->tally;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

