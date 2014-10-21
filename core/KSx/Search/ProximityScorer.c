#define C_KINO_PROXIMITYSCORER
#define C_KINO_POSTING
#define C_KINO_SCOREPOSTING
#include "KinoSearch/Util/ToolSet.h"

#include "KSx/Search/ProximityScorer.h"
#include "KinoSearch/Index/Posting/ScorePosting.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Search/Compiler.h"


ProximityScorer*
ProximityScorer_new(Similarity *sim, VArray *plists, Compiler *compiler, 
                    uint32_t within)
{
    ProximityScorer *self = (ProximityScorer*)VTable_Make_Obj(PROXIMITYSCORER);
    return ProximityScorer_init(self, sim, plists, compiler, within);

}

ProximityScorer*
ProximityScorer_init(ProximityScorer *self, Similarity *similarity, VArray *plists,
                  Compiler *compiler, uint32_t within)
{
    Matcher_init((Matcher*)self);

    // Init.
    self->anchor_set       = BB_new(0);
    self->proximity_freq   = 0.0;
    self->proximity_boost  = 0.0;
    self->first_time       = true;
    self->more             = true;
    self->within           = within;

    // Extract PostingLists out of VArray into local C array for quick access.
    self->num_elements = VA_Get_Size(plists);
    self->plists = (PostingList**)MALLOCATE(
        self->num_elements * sizeof(PostingList*));
    for (size_t i = 0; i < self->num_elements; i++) {
        PostingList *const plist = (PostingList*)CERTIFY(
            VA_Fetch(plists, i), POSTINGLIST);
        if (plist == NULL)
            THROW(ERR, "Missing element %u32", i);
        self->plists[i] = (PostingList*)INCREF(plist);
    }

    // Assign.
    self->sim       = (Similarity*)INCREF(similarity);
    self->compiler  = (Compiler*)INCREF(compiler);
    self->weight    = Compiler_Get_Weight(compiler);

    return self;
}

void
ProximityScorer_destroy(ProximityScorer *self) 
{
    if (self->plists) {
        for (size_t i = 0; i < self->num_elements; i++) {
            DECREF(self->plists[i]);
        }
        FREEMEM(self->plists);
    }
    DECREF(self->sim);
    DECREF(self->anchor_set);
    DECREF(self->compiler);
    SUPER_DESTROY(self, PROXIMITYSCORER);
}

int32_t
ProximityScorer_next(ProximityScorer *self)
{
    if (self->first_time) {
        return ProximityScorer_Advance(self, 1);
    }
    else if (self->more) {
        const int32_t target = PList_Get_Doc_ID(self->plists[0]) + 1;
        return ProximityScorer_Advance(self, target);
    }
    else {
        return 0;
    }
}

int32_t
ProximityScorer_advance(ProximityScorer *self, int32_t target) 
{
    PostingList **const plists       = self->plists;
    const uint32_t      num_elements = self->num_elements;
    int32_t             highest      = 0;

    // Reset match variables to indicate no match.  New values will be
    // assigned if a match succeeds.
    self->proximity_freq = 0.0;
    self->doc_id         = 0;

    // Find the lowest possible matching doc ID greater than the current doc
    // ID.  If any one of the PostingLists is exhausted, we're done.
    if (self->first_time) {
        self->first_time = false;

        // On the first call to Advance(), advance all PostingLists.
        for (size_t i = 0, max = self->num_elements; i < max; i++) {
            int32_t candidate = PList_Advance(plists[i], target);
            if (!candidate) {
                self->more = false;
                return 0;
            }
            else if (candidate > highest) {
                // Remember the highest doc ID so far.
                highest = candidate;
            }
        }
    }
    else {
        // On subsequent iters, advance only one PostingList.  Its new doc ID
        // becomes the minimum target which all the others must move up to.
        highest = PList_Advance(plists[0], target);
        if (highest == 0) {
            self->more = false;
            return 0;
        }
    }

    // Find a doc which contains all the terms.
    while (1) {
        bool_t agreement = true;

        // Scoot all posting lists up to at least the current minimum.
        for (uint32_t i = 0; i < num_elements; i++) {
            PostingList *const plist = plists[i];
            int32_t candidate = PList_Get_Doc_ID(plist);

            // Is this PostingList already beyond the minimum?  Then raise the
            // bar for everyone else.
            if (highest < candidate) { highest = candidate; }
            if (target < highest)    { target = highest; }

            // Scoot this posting list up.
            if (candidate < target) {
                candidate = PList_Advance(plist, target);

                // If this PostingList is exhausted, we're done.
                if (candidate == 0) {
                    self->more = false;
                    return 0;
                }

                // After calling PList_Advance(), we are guaranteed to be
                // either at or beyond the minimum, so we can assign without
                // checking and the minumum will either go up or stay the
                // same.
                highest = candidate;
            }
        }

        // See whether all the PostingLists have managed to converge on a
        // single doc ID.
        for (uint32_t i = 0; i < num_elements; i++) {
            const int32_t candidate = PList_Get_Doc_ID(plists[i]);
            if (candidate != highest) { agreement = false; }
        }

        // If we've found a doc with all terms in it, see if they form a
        // phrase.
        if (agreement && highest >= target) {
            self->proximity_freq = ProximityScorer_Calc_Proximity_Freq(self);
            if (self->proximity_freq == 0.0) {
                // No phrase.  Move on to another doc.
                target += 1;
            }
            else {
                // Success!
                self->doc_id = highest;
                return highest;
            }
        }
    }
}


static INLINE uint32_t 
SI_winnow_anchors(uint32_t *anchors_start, const uint32_t *const anchors_end,
                  const uint32_t *candidates, const uint32_t *const candidates_end,
                  uint32_t offset, uint32_t within) 
{                          
    uint32_t *anchors = anchors_start;
    uint32_t *anchors_found = anchors_start;
    uint32_t target_anchor;
    uint32_t target_candidate;

    // Safety check, so there's no chance of a bad dereference.
    if (anchors_start == anchors_end || candidates == candidates_end) {
        return 0;
    }
        
    /* This function is a loop that finds terms that can continue a phrase.
     * It overwrites the anchors in place, and returns the number remaining.
     * The basic algorithm is to alternately increment the candidates' pointer
     * until it is at or beyond its target position, and then increment the 
     * anchors' pointer until it is at or beyond its target.  The non-standard
     * form is to avoid unnecessary comparisons.  This loop has not been
     * tested for speed, but glancing at the object code produced (objdump -S)
     * it appears to be significantly faster than the nested loop alternative.
     * But given the vagaries of modern processors, it merits actual
     * testing.*/

 SPIN_CANDIDATES:
    target_candidate = *anchors + offset;
    while (*candidates < target_candidate) {
        if (++candidates == candidates_end) goto DONE;
    }
    if ((*candidates - target_candidate) < within) goto MATCH;
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
    // Return number of anchors remaining.
    return anchors_found - anchors_start; 
}

float
ProximityScorer_calc_proximity_freq(ProximityScorer *self) 
{
    PostingList **const plists   = self->plists;

    /* Create a overwriteable "anchor set" from the first posting.  
     *
     * Each "anchor" is a position, measured in tokens, corresponding to a a
     * term which might start a phrase.  We start off with an "anchor set"
     * comprised of all positions at which the first term in the phrase occurs
     * in the field.  
     * 
     * There can never be more proximity matches than instances of this first
     * term.  There may be fewer however, which we will determine by seeing
     * whether all the other terms line up at subsequent position slots.
     * 
     * Every time we eliminate an anchor from the anchor set, we splice it out
     * of the array.  So if we begin with an anchor set of (15, 51, 72) and we
     * discover that matches occur at the first and last instances of the
     * first term but not the middle one, the final array will be (15, 72).
     *
     * The number of elements in the anchor set when we are finished winnowing
     * is our proximity freq.
     */
    ScorePosting *posting = (ScorePosting*)PList_Get_Posting(plists[0]);
    uint32_t anchors_remaining = posting->freq;
    if (!anchors_remaining) { return 0.0f; }

    size_t    amount        = anchors_remaining * sizeof(uint32_t);
    uint32_t *anchors_start = (uint32_t*)BB_Grow(self->anchor_set, amount);
    uint32_t *anchors_end   = anchors_start + anchors_remaining;
    memcpy(anchors_start, posting->prox, amount);

    // Match the positions of other terms against the anchor set.
    for (uint32_t i = 1, max = self->num_elements; i < max; i++) {
        // Get the array of positions for the next term.  Unlike the anchor
        // set (which is a copy), these won't be overwritten.
        ScorePosting *posting = (ScorePosting*)PList_Get_Posting(plists[i]);
        uint32_t *candidates_start = posting->prox;
        uint32_t *candidates_end   = candidates_start + posting->freq;
        
        // Splice out anchors that don't match the next term.  Bail out if
        // we've eliminated all possible anchors.
        if (self->within == 1) { // exact phrase match
            anchors_remaining = SI_winnow_anchors(anchors_start, anchors_end,
                candidates_start, candidates_end, i, 1);
        }
        else {  // fuzzy-phrase match
            anchors_remaining = SI_winnow_anchors(anchors_start, anchors_end,
                candidates_start, candidates_end, i, self->within);
        }
        if (!anchors_remaining) { return 0.0f; }

        // Adjust end for number of anchors that remain. 
        anchors_end = anchors_start + anchors_remaining;
    }

    // The number of anchors left is the proximity freq. 
    return (float)anchors_remaining;
}

int32_t
ProximityScorer_get_doc_id(ProximityScorer *self) 
{
    return self->doc_id;
}

float
ProximityScorer_score(ProximityScorer *self) 
{
    ScorePosting *posting = (ScorePosting*)PList_Get_Posting(self->plists[0]);
    float score = Sim_TF(self->sim, self->proximity_freq) 
                * self->weight 
                * posting->weight;
    return score;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

