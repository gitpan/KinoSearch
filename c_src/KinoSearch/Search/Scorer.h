#ifndef H_KINO_SCORER
#define H_KINO_SCORER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Scorer kino_Scorer;
typedef struct KINO_SCORER_VTABLE KINO_SCORER_VTABLE;

struct kino_Similarity;
struct kino_Tally;
struct kino_HitCollector;
struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Search::Scorer", "Scorer", "KinoSearch::Util::Obj");

struct kino_Scorer {
    KINO_SCORER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Similarity *sim;
};

/* Abstract method.
 *
 *    chy_bool_t valid_state = Scorer_Next(scorer);
 *
 * Move the internal state of the scorer to the next document, which includes
 * generating the array of positions which match.  Return false when there are
 * no more documents to score.
 */
chy_bool_t
kino_Scorer_next(kino_Scorer *self);
KINO_METHOD("Kino_Scorer_Next");

/* Abstract method.
 *
 *    chy_u32_t doc = Scorer_Doc(scorer);
 *
 * Return the scorer's current document number.
 */
chy_u32_t
kino_Scorer_doc(kino_Scorer *self);
KINO_METHOD("Kino_Scorer_Doc");

/* Abstract method.
 *
 *    Tally *tally = Scorer_Tally(scorer);
 *
 * Return a Tally struct containing scoring information.
 */
struct kino_Tally*
kino_Scorer_tally(kino_Scorer *self);
KINO_METHOD("Kino_Scorer_Tally");

/*    chy_bool_t valid_state = Scorer_Skip_To(scorer, target);
 *
 * Skip to the first document number equal to or greater than the target. The
 * default implementation just calls next() over and over.
 */
chy_bool_t
kino_Scorer_skip_to(kino_Scorer *self, chy_u32_t target);
KINO_METHOD("Kino_Scorer_Skip_To");

/* Collect hits bracketed by [start] and [end], inclusive.  Collect a maximum
 * of [hits_per_seg] hits per segment.
 */
void
kino_Scorer_collect(kino_Scorer *self, struct kino_HitCollector *hc, 
                    chy_u32_t start, chy_u32_t end, 
                    chy_u32_t hits_per_seg, 
                    struct kino_VArray *seg_starts);
KINO_METHOD("Kino_Scorer_Collect");

/* Return the maximum number of subscorers that can match.  Used by
 * BooleanScorer to calculate maximum coord bonus.  Returns 1 by default.
 */
chy_u32_t
kino_Scorer_max_matchers(kino_Scorer *self);
KINO_METHOD("Kino_Scorer_Max_Matchers");

KINO_END_CLASS

#endif /* H_KINO_SCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

