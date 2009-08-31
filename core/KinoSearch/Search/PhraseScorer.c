#define C_KINO_PHRASESCORER
#define C_KINO_POSTING
#define C_KINO_SCOREPOSTING
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/PhraseScorer.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Posting/ScorePosting.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Search/Compiler.h"

/* Mark this scorer as invalid/finished.
 */
static i32_t
S_invalidate(PhraseScorer *self);

PhraseScorer*
PhraseScorer_new(Similarity *sim, VArray *plists, Compiler *compiler)
{
    PhraseScorer *self = (PhraseScorer*)VTable_Make_Obj(PHRASESCORER);
    return PhraseScorer_init(self, sim, plists, compiler);

}

PhraseScorer*
PhraseScorer_init(PhraseScorer *self, Similarity *similarity, VArray *plists,
                  Compiler *compiler)
{
    u32_t i;

    Matcher_init((Matcher*)self);

    /* Init. */
    self->anchor_set       = BB_new(0);
    self->phrase_freq      = 0.0;
    self->phrase_boost     = 0.0;
    self->first_time       = true;
    self->more             = true;

    /* Extract posting lists for quick access. */
    self->num_elements   = VA_Get_Size(plists);
    self->plists         = MALLOCATE(self->num_elements, PostingList*);
    for (i = 0; i < self->num_elements; i++) {
        PostingList *const plist = (PostingList*)VA_Fetch(plists, i);
        if (plist == NULL)
            THROW(ERR, "Missing element %u32", i);
        self->plists[i] = (PostingList*)INCREF(plist);
    }

    /* Assign. */
    self->sim       = (Similarity*)INCREF(similarity);
    self->compiler  = (Compiler*)INCREF(compiler);
    self->weight    = Compiler_Get_Weight(compiler);

    return self;
}

void
PhraseScorer_destroy(PhraseScorer *self) 
{
    if (self->plists) {
        PostingList **plists = self->plists;
        size_t i;
        for (i = 0; i < self->num_elements; i++) {
            DECREF(plists[i]);
        }
        FREEMEM(self->plists);
    }

    DECREF(self->sim);
    DECREF(self->anchor_set);
    DECREF(self->compiler);

    SUPER_DESTROY(self, PHRASESCORER);
}

static i32_t
S_invalidate(PhraseScorer *self)
{
    self->more = false;
    return 0;
}

i32_t
PhraseScorer_next(PhraseScorer *self)
{
    if (self->first_time) {
        return PhraseScorer_Advance(self, 1);
    }
    else if (self->more) {
        const i32_t target = PList_Get_Doc_ID(self->plists[0]) + 1;
        return PhraseScorer_Advance(self, target);
    }
    else {
        return 0;
    }
}

i32_t
PhraseScorer_advance(PhraseScorer *self, i32_t target) 
{
    PostingList **const plists       = self->plists;
    const u32_t         num_elements = self->num_elements;
    i32_t               highest      = 0;

    self->phrase_freq = 0.0;
    self->doc_id      = 0;

    if (self->first_time) {
        i32_t candidate;
        u32_t i;

        self->first_time = false;
        /* Advance all posting lists. */
        for (i = 0; i < num_elements; i++) {
            candidate = PList_Next(plists[i]);
            if (!candidate)
                return S_invalidate(self);
            else if (candidate > highest)
                highest = candidate;
        }
    }
    else {
        /* Seed the search, advancing only one posting list. */
        highest = PList_Next(plists[0]);
        if (highest == 0)
            return S_invalidate(self);
    }

    /* Find a doc which contains all the terms. */
    while (1) {
        u32_t i;
        bool_t agreement = true;

        /* Scoot all posting lists up. */
        for (i = 0; i < num_elements; i++) {
            PostingList *const plist = plists[i];
            i32_t candidate = PList_Get_Doc_ID(plist);

            /* Maybe raise the bar. */
            if (highest < candidate)
                highest = candidate;
            if (target < highest)
                target = highest;

            /* Scoot this posting list up. */
            if (candidate < target) {
                /* If somebody's raised the bar, don't wait till next loop. */
                highest = PList_Advance(plist, target);
                if (highest == 0)
                    return S_invalidate(self);
            }
        }

        /* If posting lists don't agree, send back through the loop. */
        for (i = 0; i < num_elements; i++) {
            PostingList *const plist = plists[i];
            const i32_t candidate    = PList_Get_Doc_ID(plist);
            if (candidate != highest)
                agreement = false;
        }

        if (agreement && highest >= target) {
            self->phrase_freq = PhraseScorer_Calc_Phrase_Freq(self);
            if (self->phrase_freq == 0.0) {
                target += 1;
            }
            else {
                /* Success! */
                self->doc_id   = highest;
                return highest;
            }
        }
    }
}

static INLINE u32_t 
SI_winnow_anchors(u32_t *anchors_start, const u32_t *const anchors_end,
                  const u32_t *candidates, const u32_t *const candidates_end,
                  u32_t offset) 
{                          
    u32_t *anchors = anchors_start;
    u32_t *anchors_found = anchors_start;
    u32_t target_anchor;
    u32_t target_candidate;

    /* Safety check, so there's no chance of a bad dereference. */
    if (anchors_start == anchors_end || candidates == candidates_end)
        return 0;

    /* This function is a loop that finds terms that can continue a phrase.
     * It overwrites the anchors in place, and returns the number remaining.
     * The basic algorithm is to alternately increment the candidates' pointer
     * until it is at or beyond its target position, and then increment the 
     * anchors' pointer until it is at or beyond its target.  The non-standard
     * form is to avoid unnecessary comparisons.  I have not tested this
     * loop for speed, but glancing at the object code produced (objdump -S) 
     * it appears to be significantly faster than the nested loop alternative.
     * But given the vagaries of modern processors, it merits actual
     * testing.*/

 SPIN_CANDIDATES:
    target_candidate = *anchors + offset;
    while (*candidates < target_candidate) {
        if (++candidates == candidates_end) goto DONE;
    } 
    if (*candidates == target_candidate) goto MATCH;
    goto SPIN_ANCHORS;  

 SPIN_ANCHORS: 
    target_anchor = *candidates - offset;
    while (*anchors < target_anchor) { 
        if (++anchors == anchors_end) goto DONE;
    };
    if (*anchors == target_anchor) goto MATCH;
    goto SPIN_CANDIDATES;  

 MATCH:       
    *anchors_found++ = *anchors;
    if (++anchors == anchors_end) goto DONE;
    goto SPIN_CANDIDATES; 

 DONE:
    /* Return number of anchors remaining. */
    return anchors_found - anchors_start; 
}

float
PhraseScorer_calc_phrase_freq(PhraseScorer *self) 
{
    PostingList **const plists   = self->plists;
    u32_t i;

    /* Create a overwriteable anchor set from the first posting. */
    ScorePosting *posting = (ScorePosting*)PList_Get_Posting(plists[0]);
    u32_t anchors_remaining = posting->freq;
    size_t amount = anchors_remaining * sizeof(u32_t);
    ByteBuf *const anchor_set  = self->anchor_set;
    u32_t *anchors_start, *anchors_end, *anchors;

    anchors_start = (u32_t*)BB_Grow(anchor_set, amount);
    anchors_end   = anchors_start + anchors_remaining;
    anchors       = anchors_start;
    memcpy(anchors_start, posting->prox, amount);

    /* Match the positions of other terms against the anchor set. */
    anchors_remaining = anchors_end - anchors_start;
    for (i = 1; i < self->num_elements && anchors_remaining; i++) {
        /* Prepare the non-overwritten list of potential next terms. */
        ScorePosting *posting = (ScorePosting *)PList_Get_Posting(plists[i]);
        u32_t *candidates_start = posting->prox;
        u32_t *candidates_end   = candidates_start + posting->freq;

        /* Reduce anchor_set in place to those that match the next term. */
        anchors_remaining = SI_winnow_anchors(anchors_start, anchors_end,
            candidates_start, candidates_end, i);
        /* Adjust end for number of anchors that remain. */
        anchors_end = anchors_start + anchors_remaining;
    }

    /* The number of anchors left is the phrase freq. */
    return (float)anchors_remaining;
}

i32_t
PhraseScorer_get_doc_id(PhraseScorer *self) 
{
    return self->doc_id;
}

float
PhraseScorer_score(PhraseScorer *self) 
{
    ScorePosting *posting = (ScorePosting*)PList_Get_Posting(self->plists[0]);
    float score = Sim_TF(self->sim, self->phrase_freq) 
                * self->weight 
                * posting->weight;
    return score;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

