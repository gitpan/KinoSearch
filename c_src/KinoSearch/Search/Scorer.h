#ifndef H_KINO_SCORER
#define H_KINO_SCORER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Scorer kino_Scorer;
typedef struct KINO_SCORER_VTABLE KINO_SCORER_VTABLE;

struct kino_Similarity;
struct kino_HitCollector;
struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Search::Scorer", "Scorer", "KinoSearch::Util::Obj");

struct kino_Scorer {
    KINO_SCORER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Similarity *sim;
    struct kino_ByteBuf    *raw_prox_bb;
    kino_u32_t             *prox;
    kino_u32_t              num_prox;
};

/* Abstract method.
 *
 *    kino_bool_t valid_state = Scorer_Next(scorer);
 *
 * Move the internal state of the scorer to the next document, which includes
 * generating the array of positions which match.  Return false when there are
 * no more documents to score.
 */
KINO_METHOD("Kino_Scorer_Next",
kino_bool_t
kino_Scorer_next(kino_Scorer *self));

/* Abstract method.
 *
 *    kino_u32_t doc = Scorer_Doc(scorer);
 *
 * Return the scorer's current document number.
 */
KINO_METHOD("Kino_Scorer_Doc",
kino_u32_t
kino_Scorer_doc(kino_Scorer *self));

/* Abstract method.
 *
 *    float score = Scorer_Score(scorer);
 * 
 * Calculate and return a score for the scorer's current document.
 */
KINO_METHOD("Kino_Scorer_Score",
float
kino_Scorer_score(kino_Scorer *self));

/*    kino_bool_t valid_state = Scorer_Skip_To(scorer, target);
 *
 * Skip to the first document number equal to or greater than the target. The
 * default implementation just calls next() over and over.
 */
KINO_METHOD("Kino_Scorer_Skip_To",
kino_bool_t
kino_Scorer_skip_to(kino_Scorer*, kino_u32_t));

/* Collect hits bracketed by [start] and [end], inclusive.  Collect a maximum
 * of [prune_factor] hits per segment.
 */
KINO_METHOD("Kino_Scorer_Score_Batch",
void
kino_Scorer_score_batch(kino_Scorer *self, struct kino_HitCollector *hc, 
                        kino_u32_t start, kino_u32_t end, 
                        kino_u32_t prune_factor, 
                        struct kino_VArray *seg_starts));

KINO_END_CLASS

#endif /* H_KINO_SCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

