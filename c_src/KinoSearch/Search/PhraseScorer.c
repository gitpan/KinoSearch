#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_PHRASESCORER_VTABLE
#include "KinoSearch/Search/PhraseScorer.r"

#include "KinoSearch/Index/TermDocs.r"
#include "KinoSearch/Search/Similarity.r"

/* Mark this scorer as invalid/finished.
 */
static bool_t
invalidate(PhraseScorer *self);

/* Return the highest value for doc() from an array of TermDocs.
 */
static u32_t
highest_doc(TermDocs **termdocs, u32_t num_elements);

/* Add up positional boost, which is probably  pretty significant.  */
static float 
calc_pos_boost(PhraseScorer *self);

/* Build up the array of positions which match this query within the current
 * doc.
 */
static void
build_prox(PhraseScorer *self);

#define KINO_PHRASESCORER_SENTINEL 0xFFFFFFFF

PhraseScorer*
PhraseScorer_new(kino_u32_t num_elements, struct kino_TermDocs **term_docs, 
                 kino_u32_t *phrase_offsets, float weight_val,
                 struct kino_Similarity *sim, kino_u32_t slop)
{
    u32_t i;
    CREATE(self, PhraseScorer, PHRASESCORER);

    /* init */
    self->doc_num          = KINO_PHRASESCORER_SENTINEL;
    self->slop             = 0;
    self->num_elements     = 0;
    self->term_docs        = NULL;
    self->phrase_offsets   = NULL;
    self->anchor_set       = BB_new(0);
    self->raw_prox_bb      = BB_new(0);
    self->num_prox         = 0;
    self->phrase_freq      = 0.0;
    self->phrase_boost     = 0.0;
    self->weight_value     = 0.0;
    self->first_time       = true;
    self->more             = true;

    /* assign */
    REFCOUNT_INC(sim);
    self->sim             = sim;
    self->num_elements    = num_elements;
    self->term_docs       = term_docs;
    self->phrase_offsets  = phrase_offsets;
    self->weight_value    = weight_val;
    self->sim             = sim;
    self->slop            = slop;

    /* increment refcounts */
    for (i = 0; i < num_elements; i++) {
        REFCOUNT_INC(term_docs[i]);
    }

    return self;
}

void
PhraseScorer_destroy(PhraseScorer *self) 
{
    size_t i;
    TermDocs **term_docs = self->term_docs;

    for (i = 0; i < self->num_elements; i++) {
        REFCOUNT_DEC(term_docs[i]);
    }
    free(self->term_docs);
    free(self->phrase_offsets);

    REFCOUNT_DEC(self->raw_prox_bb);
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->anchor_set);

    free(self);
}

static bool_t
invalidate(PhraseScorer *self)
{
    self->more = false;
    return false;
}

static u32_t
highest_doc(TermDocs **term_docs, u32_t num_elements)
{
    u32_t highest = 0;

    while(num_elements--) {
        u32_t candidate = TermDocs_Get_Doc(*term_docs); 
        if (candidate > highest)
            highest = candidate;
        term_docs++;
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
        const u32_t target = TermDocs_Get_Doc(self->term_docs[0]) + 1;
        return Scorer_Skip_To(self, target);
    }
    else {
        return false;
    }
}

bool_t
PhraseScorer_skip_to(PhraseScorer *self, u32_t target) 
{
    TermDocs **const term_docs    = self->term_docs;
    const u32_t      num_elements = self->num_elements;
    u32_t            highest      = 0;

    self->phrase_freq = 0.0;
    self->doc_num = KINO_PHRASESCORER_SENTINEL; 

    if (self->first_time) {
        u32_t i;
        self->first_time = false;
        /* advance all term_docs */
        for (i = 0; i < num_elements; i++) {
            if ( !TermDocs_Next(term_docs[i]) )
                return invalidate(self);
        }
        highest = highest_doc(term_docs, num_elements);
    }
    else {
        /* seed the search, advancing only one term_docs */
        if ( !TermDocs_Next(term_docs[0]) )
            return false;
        highest = TermDocs_Get_Doc(term_docs[0]);
    }

    /* find a doc which contains all the terms */
    while (1) {
        u32_t i;
        bool_t agreement = true;

        /* scoot all term_docs up */
        for (i = 0; i < num_elements; i++) {
            TermDocs *const td = term_docs[i];
            u32_t candidate = TermDocs_Get_Doc(td);

            /* maybe raise the bar */
            if (highest < candidate)
                highest = candidate;
            if (target < highest)
                target = highest;

            /* scoot this term_docs up */
            if (candidate < target) {
                if ( !TermDocs_Skip_To(td, target) )
                    return invalidate(self);
                /* if somebody's raised the bar, don't wait till next loop */
                highest = TermDocs_Get_Doc(td);
            }
        }

        /* if term_docs don't agree, send back through the loop */
        for (i = 0; i < num_elements; i++) {
            TermDocs *const td = term_docs[i];
            const u32_t candidate = TermDocs_Get_Doc(td);
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
    ByteBuf *const anchor_set = self->anchor_set;
    u32_t *anchors            = (u32_t*)anchor_set->ptr;
    u32_t *anchors_end        = (u32_t*)BBEND(anchor_set);
    u32_t *dest;

    /* set num_prox */
    self->num_prox = (anchor_set->len / sizeof(u32_t)) * self->num_elements;
    
    /* allocate space for the prox as needed and get a pointer to write to */
    BB_Grow(self->raw_prox_bb, self->num_prox * sizeof(u32_t));
    self->raw_prox_bb->len = self->num_prox * sizeof(u32_t);
    dest = (u32_t*)self->raw_prox_bb->ptr;
    self->prox = dest;

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
    TermDocs **const term_docs = self->term_docs;
    ByteBuf *const anchor_set = self->anchor_set;
    ByteBuf *const first_set  = TermDocs_Get_Positions(term_docs[0]);
    u32_t  phrase_offset = self->phrase_offsets[0];
    u32_t  i;
    u32_t *anchors, *anchors_start, *anchors_end;

    /* create an anchor set */
    BB_Copy_Str(anchor_set, first_set->ptr, first_set->len);
    anchors_start = (u32_t*)anchor_set->ptr;
    anchors       = anchors_start;
    anchors_end   = (u32_t*)BBEND(anchor_set);
    while(anchors < anchors_end) {
        *anchors++ -= phrase_offset;
    }

    /* match the positions of other terms against the anchor set */
    for (i = 1; i < self->num_elements; i++) {
        ByteBuf *const positions = TermDocs_Get_Positions(term_docs[i]);
        u32_t *candidates      = (u32_t*)positions->ptr;
        u32_t *candidates_end  = (u32_t*)BBEND(positions);

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

float
PhraseScorer_score(PhraseScorer *self) 
{
    /* calculate raw score */
    float score =  Sim_TF(self->sim, self->phrase_freq) 
         * self->weight_value;

    /* factor in pos boost */
    score *= calc_pos_boost(self);

    return score;
}

static float
calc_pos_boost(PhraseScorer *self)
{
    float pos_boost         = 0.0f;
    float field_boost       = 0.0f;
    float *norm_decoder     = self->sim->norm_decoder;
    TermDocs **term_docs    = self->term_docs;
    u32_t *phrase_offsets   = self->phrase_offsets;
    ByteBuf *anchor_set     = self->anchor_set;
    u32_t *anchors          = (u32_t*)anchor_set->ptr;
    u32_t *anchors_start    = anchors;
    u32_t *anchors_end      = (u32_t*)BBEND(anchor_set);
    u32_t num_anchors       = anchors_end - anchors_start;
    u32_t elem_inc;
    
    /* find the boost associated with every posting in a matching phrase */
    for (elem_inc = 0; elem_inc < self->num_elements; elem_inc++) {
        TermDocs *td           = term_docs[elem_inc];
        ByteBuf *boosts_bb     = TermDocs_Get_Boosts(td);

        if (boosts_bb->len > 0) {
            u8_t *encoded_boosts   = (u8_t*)boosts_bb->ptr;
            ByteBuf *positions_bb  = TermDocs_Get_Positions(td);
            u32_t *positions       = (u32_t*)positions_bb->ptr;

            for (anchors = anchors_start; anchors < anchors_end; anchors++) {
                u32_t target = *anchors + phrase_offsets[elem_inc];
                u32_t i = 0;

                while (positions[i] != target) {
                    i++;
                }
                pos_boost += norm_decoder[ encoded_boosts[i] ];
            }
        }
        else {
            field_boost += norm_decoder[ TermDocs_Get_Field_Boost_Byte(td) ];
        }
    }
    
    /* average the boosts */
    if (pos_boost > 0.0f)
        self->phrase_boost = pos_boost / ( self->num_elements * num_anchors );
    else 
        self->phrase_boost = field_boost / self->num_elements;
    return self->phrase_boost;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

