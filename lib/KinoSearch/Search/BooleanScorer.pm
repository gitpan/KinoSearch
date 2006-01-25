package KinoSearch::Search::BooleanScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = __PACKAGE__->init_instance_vars();

sub new {
    my $self = shift->SUPER::new;
    verify_args(\%instance_vars, @_);
    my %args = (%instance_vars, @_);
    $self->set_similarity( $args{similarity} );
    $self->_init_child;
    return $self;
}


# Add a scorer for a sub-query of the BooleanQuery.
sub add_subscorer {
    my ( $self, $subscorer, $occur ) = @_;
    push @{ $self->_get_subscorer_storage }, $subscorer;
    $self->_add_subscorer( $subscorer, $occur );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::BooleanScorer

void
_init_child(obj)
    Scorer *obj;
PPCODE:
    Kino_BoolScorer_init_child(obj);

void 
_add_subscorer(obj, subscorer, occur)
    Scorer *obj;
    Scorer *subscorer;
    char   *occur;
PPCODE:
    Kino_BoolScorer_add_subscorer(obj, subscorer, occur);

SV*
_boolean_scorer_set_or_get(obj, ...)
    Scorer* obj;
ALIAS:
    _get_subscorer_storage = 2
PREINIT:
    BoolScorerChild* child;
CODE:
{
    child = (BoolScorerChild*)obj->child;

    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $scorer->set_xxxxxx($val)");

    switch (ix) {

    case 2:  RETVAL = newRV((SV*)child->subscorers_av);
             break;
    }
}
OUTPUT: RETVAL

void
DESTROY(obj)
    Scorer *obj;
PPCODE:
    Kino_BoolScorer_destroy(obj);

__H__

#ifndef H_KINO_BOOLEAN_SCORER
#define H_KINO_BOOLEAN_SCORER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchSearchScorer.h"
#include "KinoSearchUtilMemManager.h"

#define KINO_MATCH_BATCH_SIZE (1 << 11)
#define KINO_MATCH_BATCH_DOC_MASK (KINO_MATCH_BATCH_SIZE - 1)

/* A MatchBatch can hold scoring data for 2048 documents.  */

typedef struct matchbatch {
    U32       count;
    float    *scores;
    U32      *matcher_counts;
    U32      *bool_masks;
    U32      *recent_docs;
} MatchBatch;

typedef struct boolsubscorer {
    Scorer *scorer;
    U32     bool_mask;
    bool    done;
    struct boolsubscorer *next_subscorer;
} BoolSubScorer;

typedef struct boolscorerchild {
    U32            doc;
    U32            end;
    U32            max_coord;
    float         *coord_factors;
    U32            required_mask;
    U32            prohibited_mask;
    U32            next_mask;
    MatchBatch    *mbatch;
    BoolSubScorer *subscorers; /* linked list */
    AV            *subscorers_av;
} BoolScorerChild;

void Kino_BoolScorer_init_child(Scorer*);
MatchBatch* Kino_BoolScorer_new_mbatch();
void Kino_BoolScorer_clear_mbatch(MatchBatch*);
void Kino_BoolScorer_compute_coord_factors(Scorer*);
void Kino_BoolScorer_add_subscorer(Scorer*, Scorer*, char*);
bool Kino_BoolScorer_next(Scorer*);
float Kino_BoolScorer_score(Scorer*);
U32 Kino_BoolScorer_doc(Scorer*);
void Kino_BoolScorer_destroy(Scorer*);

#endif /* include guard */

__C__

#include "KinoSearchSearchBooleanScorer.h"

void
Kino_BoolScorer_init_child(Scorer *scorer) {
    BoolScorerChild *child;

    Kino_New(0, child, 1, BoolScorerChild);
    scorer->child = child;

    /* define Scorer's abstract methods */
    scorer->next  = Kino_BoolScorer_next;
    scorer->doc   = Kino_BoolScorer_doc;
    scorer->score = Kino_BoolScorer_score;

    /* init */
    child->end             = 0;
    child->max_coord       = 1;
    child->coord_factors   = NULL;
    child->required_mask   = 0;
    child->prohibited_mask = 0;
    child->next_mask       = 1;
    child->mbatch          = Kino_BoolScorer_new_mbatch();
    child->subscorers      = NULL;
    child->subscorers_av   = newAV();
}

MatchBatch*
Kino_BoolScorer_new_mbatch() {
    MatchBatch* mbatch;

    /* allocate and init */
    Kino_New(0, mbatch, 1, MatchBatch);
    Kino_New(0, mbatch->scores, KINO_MATCH_BATCH_SIZE, float);
    Kino_New(0, mbatch->matcher_counts, KINO_MATCH_BATCH_SIZE, U32);
    Kino_New(0, mbatch->bool_masks, KINO_MATCH_BATCH_SIZE, U32);
    Kino_New(0, mbatch->recent_docs, KINO_MATCH_BATCH_SIZE, U32);
    mbatch->count    = 0;

    return mbatch;
}

/* Return a MatchBatch to a "zeroed" state.  Only the matcher_counts and the
 * count are actually cleared; the rest get initialized the next time a doc
 * gets captured. */
void
Kino_BoolScorer_clear_mbatch(MatchBatch *mbatch) {
    Zero(mbatch->matcher_counts, KINO_MATCH_BATCH_SIZE, U32);
    mbatch->count = 0;
}

/* BooleanScorers award bonus points to documents which match multiple
 * subqueries.  This routine calculates the size of the bonuses. */
void
Kino_BoolScorer_compute_coord_factors(Scorer *scorer) {
    BoolScorerChild *child;
    float           *coord_factors;
    I32              i;

    child = (BoolScorerChild*)scorer->child;

    Kino_New(0, child->coord_factors, (child->max_coord + 1), float);
    coord_factors = child->coord_factors;

    for (i = 0; i <= child->max_coord; i++) {
        *coord_factors++ 
            = scorer->sim->coord(scorer->sim, i, child->max_coord);
    }
}

void
Kino_BoolScorer_add_subscorer(Scorer* main_scorer, Scorer* subscorer, 
                              char *occur) {
    BoolScorerChild *child;
    U32              mask;
    BoolSubScorer   *bool_subscorer;

    child = (BoolScorerChild*)main_scorer->child;
    
    Kino_New(0, bool_subscorer, 1, BoolSubScorer);
    bool_subscorer->scorer = subscorer;

    /* if this scorer is required or negated, assign it a unique mask bit. */
    if (strnEQ(occur, "SHOULD", 6)) {
        bool_subscorer->bool_mask = 0;
        child->max_coord++;
    }
    else {
        if (child->next_mask == 0) {
            Kino_confess("more than 32 required or prohibited clauses");
        }
        bool_subscorer->bool_mask = child->next_mask;
        child->next_mask <<= 1;

        if (strnEQ(occur, "MUST_NOT", 8)) {
            child->prohibited_mask |= bool_subscorer->bool_mask;
        }
        else { /* "MUST" occur */
            child->max_coord++;
            child->required_mask |= bool_subscorer->bool_mask;
        }
    }

    /* prime the pump */
    bool_subscorer->done = !subscorer->next(subscorer);

    /* link up the linked list of subscorers */
    bool_subscorer->next_subscorer = child->subscorers;
    child->subscorers = bool_subscorer;
}

bool
Kino_BoolScorer_next(Scorer* scorer) {
    BoolScorerChild *child;
    MatchBatch      *mbatch;
    bool             more;
    U32              doc;
    U32              masked_doc;
    U32              bool_mask;
    BoolSubScorer   *sub;

    child = (BoolScorerChild*)scorer->child;
    mbatch = child->mbatch;

    do {
        while (mbatch->count-- > 0) { 

            /* check to see if the doc is prohibited */
            doc        = mbatch->recent_docs[ mbatch->count ];
            masked_doc = doc & KINO_MATCH_BATCH_DOC_MASK;
            bool_mask  = mbatch->bool_masks[masked_doc];
            if (   (bool_mask & child->prohibited_mask) == 0
                && (bool_mask & child->required_mask) == child->required_mask
            ) {
                /* it's not prohibited, so next() was successful */
                child->doc = doc;
                return 1;
            }
        }

        /* refill the queue, processing all docs within the next range */
        Kino_BoolScorer_clear_mbatch(mbatch);
        more = 0;
        child->end += KINO_MATCH_BATCH_SIZE;
        
        /* iterate through subscorers, caching results to the MatchBatch */
        for (sub = child->subscorers; sub != NULL; sub = sub->next_subscorer) {
            Scorer *scorer = sub->scorer;
            while (!sub->done && scorer->doc(scorer) < child->end) {
                doc        = scorer->doc(scorer);
                masked_doc = doc & KINO_MATCH_BATCH_DOC_MASK;
                if (mbatch->matcher_counts[masked_doc] == 0) {
                    /* first scorer to hit this doc */
                    mbatch->recent_docs[mbatch->count] = doc;
                    mbatch->count++;
                    mbatch->matcher_counts[masked_doc] = 1;
                    mbatch->scores[masked_doc]     = scorer->score(scorer);
                    mbatch->bool_masks[masked_doc] = sub->bool_mask;
                }
                else {
                    mbatch->matcher_counts[masked_doc]++;
                    mbatch->scores[masked_doc] += scorer->score(scorer);
                    mbatch->bool_masks[masked_doc] |= sub->bool_mask;
                }

                /* check whether this scorer is exhausted */
                sub->done = !scorer->next(scorer);
            }
            /* if at least one scorer succeeded, loop back */
            if (!sub->done) {
                more = 1;
            }
        } 
    } while (mbatch->count > 0 || more);

    /* out of docs!  we're done. */
    return 0;
}

float
Kino_BoolScorer_score(Scorer* scorer){
    BoolScorerChild *child;
    MatchBatch      *mbatch;
    U32              masked_doc;
    child = (BoolScorerChild*)scorer->child;
    mbatch = child->mbatch;

    if (child->coord_factors == NULL) {
        Kino_BoolScorer_compute_coord_factors(scorer);
    }

    /* retrieve the docs accumulated score from the MatchBatch */
    masked_doc = child->doc & KINO_MATCH_BATCH_DOC_MASK;
    float score = mbatch->scores[masked_doc];

    /* assign bonus for multi-subscorer matches */
    score *= child->coord_factors[ mbatch->matcher_counts[masked_doc] ];
    return score;
}

U32
Kino_BoolScorer_doc(Scorer* scorer) {
    BoolScorerChild *child = (BoolScorerChild*)scorer->child;
    return child->doc;
}

void
Kino_BoolScorer_destroy(Scorer * scorer) {
    BoolSubScorer   *sub, *next_sub;
    BoolScorerChild *child;
    child = (BoolScorerChild*)scorer->child;

    if (child->mbatch != NULL) {
        Kino_Safefree(child->mbatch->scores);
        Kino_Safefree(child->mbatch->matcher_counts);
        Kino_Safefree(child->mbatch->bool_masks);
        Kino_Safefree(child->mbatch->recent_docs);
        Kino_Safefree(child->mbatch);
    }
    
    sub = child->subscorers;
    while (sub != NULL) {
        next_sub = sub->next_subscorer;
        Kino_Safefree(sub);
        sub = next_sub;
        /* individual scorers will be GC'd on their own by Perl */
    }

    if (child->coord_factors != NULL)
        Kino_Safefree(child->coord_factors);

    SvREFCNT_dec((SV*)child->subscorers_av);

    Kino_Safefree(child);
    Kino_Scorer_destroy(scorer);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::BooleanScorer - scorer for BooleanQuery

=head1 DESCRIPTION 

Implementation of Scorer for BooleanQuery.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut
