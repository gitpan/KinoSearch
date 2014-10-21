package KinoSearch::Search::TermScorer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

use KinoSearch::Search::Scorer qw( %score_batch_args );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    weight       => undef,
    term_docs    => undef,
    norms_reader => undef,
);

sub new {
    my $self = shift->SUPER::new;
    verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    $self->_init_child;

    $self->_set_term_docs( $args{term_docs} );
    $self->_set_norms( $args{norms_reader}->get_bytes );
    $self->set_similarity( $args{similarity} );
    $self->_set_weight( $args{weight} );
    $self->_set_weight_value( $args{weight}->get_value );

    $self->_fill_score_cache;

    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::TermScorer

void
_init_child(scorer)
    Scorer *scorer;
PPCODE:
    Kino_TermScorer_init_child(scorer);

=for comment

Build up a cache of scores for common (i.e. low) freqs, so they don't have to
be continually recalculated.

=cut

void
_fill_score_cache(scorer)
    Scorer* scorer;
PPCODE:
    Kino_TermScorer_fill_score_cache(scorer);

void
score_batch(scorer, ...)
    Scorer *scorer;
PREINIT:
    HV           *args_hash;
    U32           start, end;
    HitCollector *hc;
PPCODE:
    /* process hash-style params */
    Kino_Verify_build_args_hash(args_hash, 
        "KinoSearch::Search::TermScorer::score_batch_args", 1);
    Kino_extract_struct_from_hv(args_hash, hc, "hit_collector", 13, 
        HitCollector*, "KinoSearch::Search::HitCollector");
    start = (U32)SvUV( Kino_Verify_extract_arg(args_hash, "start", 5) );
    end   = (U32)SvUV( Kino_Verify_extract_arg(args_hash, "end", 3) );

    Kino_TermScorer_score_batch(scorer, start, end, hc);

SV*
_term_scorer_set_or_get(scorer, ...)
    Scorer *scorer;
ALIAS:
    _set_term_docs    = 1
    _get_term_docs    = 2
    _set_weight       = 3
    _get_weight       = 4
    _set_weight_value = 5
    _get_weight_value = 6
    _set_norms        = 7
    _get_norms        = 8
PREINIT:
    TermScorerChild *child;
CODE:
{
    child = (TermScorerChild*)scorer->child;
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $scorer->set_xxxxxx($val)");

    switch (ix) {

    case 1:  SvREFCNT_dec(child->term_docs_sv);
             child->term_docs_sv = newSVsv( ST(1) );
             Kino_extract_struct( child->term_docs_sv, child->term_docs, 
                TermDocs*, "KinoSearch::Index::TermDocs");
             /* fall through */
    case 2:  RETVAL = newSVsv(child->term_docs_sv);
             break;

    case 3:  SvREFCNT_dec(child->weight_sv); 
             if (!sv_derived_from( ST(1), "KinoSearch::Search::Weight"))
                Kino_confess("not a KinoSearch::Search::Weight");
             child->weight_sv = newSVsv( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVsv(child->weight_sv);
             break;

    case 5:  child->weight_value = SvNV( ST(1) );
             /* fall through */
    case 6:  RETVAL = newSVnv(child->weight_value);
             break;

    case 7:  SvREFCNT_dec(child->norms_sv);
             child->norms_sv = newSVsv( ST(1) );
             {
                 SV* bytes_deref_sv;
                 bytes_deref_sv = SvRV(child->norms_sv);
                 if (SvPOK(bytes_deref_sv)) {
                     child->norms = (unsigned char*)SvPVX(bytes_deref_sv);
                 }
                 else {
                     child->norms = NULL;
                 }
             }
             /* fall through */
    case 8:  RETVAL = newSVsv(child->norms_sv);
             break;
    }
}
OUTPUT: RETVAL

void
DESTROY(scorer)
    Scorer *scorer;
PPCODE:
    Kino_TermScorer_destroy(scorer);

__H__

#ifndef H_KINO_TERM_SCORER
#define H_KINO_TERM_SCORER 1

#define KINO_SCORE_CACHE_SIZE 32
#define KINO_TERM_SCORER_SENTINEL 0xFFFFFFFF

#include "EXTERN.h"
#include "perl.h"
#include "KinoSearchIndexTermDocs.h"
#include "KinoSearchSearchHitCollector.h"
#include "KinoSearchSearchScorer.h"
#include "KinoSearchUtilMemManager.h"

typedef struct termscorerchild {
    U32            doc;
    TermDocs*      term_docs;
    U32            pointer;
    U32            pointer_max;
    float          weight_value;
    unsigned char *norms;
    float         *score_cache;
    U32           *doc_nums;
    U32           *freqs;
    SV            *doc_nums_sv;
    SV            *freqs_sv;
    SV            *weight_sv;
    SV            *term_docs_sv;
    SV            *norms_sv;
} TermScorerChild;

void Kino_TermScorer_init_child(Scorer*);
void Kino_TermScorer_fill_score_cache(Scorer*);
bool Kino_TermScorer_next(Scorer*);
float Kino_TermScorer_score(Scorer*);
void  Kino_TermScorer_score_batch(Scorer*, U32, U32, HitCollector*);
U32 Kino_TermScorer_doc(Scorer*);
void Kino_TermScorer_destroy(Scorer*);

#endif /* include guard */

__C__

#include "KinoSearchSearchTermScorer.h"

void
Kino_TermScorer_init_child(Scorer *scorer){
    TermScorerChild *child;

    /* allocate */
    Kino_New(0, child, 1, TermScorerChild);
    scorer->child       = child;
    child->doc_nums_sv  = newSV(0);
    child->freqs_sv     = newSV(0);

    /* define abstract methods */
    scorer->next  = Kino_TermScorer_next;
    scorer->doc   = Kino_TermScorer_doc;
    scorer->score = Kino_TermScorer_score;

    /* init */
    child->doc          = 0;
    child->term_docs    = NULL;
    child->pointer      = 0;
    child->pointer_max  = 0;
    child->doc_nums     = NULL;
    child->freqs        = NULL;
    child->weight_value = 0.0;
    child->norms        = NULL;
    child->score_cache  = NULL;
    child->weight_sv    = &PL_sv_undef;
    child->term_docs_sv = &PL_sv_undef;
    child->norms_sv     = &PL_sv_undef;
}   

void
Kino_TermScorer_fill_score_cache(Scorer *scorer) {
    TermScorerChild *child;
    float           *cache_ptr;
    int              i;

    child = (TermScorerChild*)scorer->child;
    Kino_Safefree(child->score_cache);
    Kino_New(0, child->score_cache, KINO_SCORE_CACHE_SIZE, float);

    cache_ptr     = child->score_cache;
    for (i = 0; i < KINO_SCORE_CACHE_SIZE; i++) {
        *cache_ptr++ = scorer->sim->tf(scorer->sim, i) * child->weight_value;
    }
}

void
Kino_TermScorer_destroy(Scorer *scorer) {
    TermScorerChild *child;
    child = (TermScorerChild*)scorer->child;

    Kino_Safefree(child->score_cache);

    SvREFCNT_dec(child->term_docs_sv);
    SvREFCNT_dec(child->norms_sv);
    SvREFCNT_dec(child->weight_sv);
    SvREFCNT_dec(child->doc_nums_sv);
    SvREFCNT_dec(child->freqs_sv);

    Kino_Safefree(child);
    Kino_Scorer_destroy(scorer);
}

bool
Kino_TermScorer_next(Scorer* scorer) {
    TermScorerChild *child = (TermScorerChild*)scorer->child;
        
    /* refill the queue if needed */
    if (++child->pointer >= child->pointer_max) {
        child->pointer_max = child->term_docs->read(child->term_docs, 
            child->doc_nums_sv, child->freqs_sv, 1024);
        child->doc_nums = (U32*)SvPV_nolen(child->doc_nums_sv);
        child->freqs    = (U32*)SvPV_nolen(child->freqs_sv);
        if (child->pointer_max != 0) {
            child->pointer = 0;
        }
        else {
            child->doc = KINO_TERM_SCORER_SENTINEL;
            /* TODO Lucene calls termDocs.close() here. */
            return 0;
        }
 
    }
    child->doc = child->doc_nums[child->pointer];
    return 1;
}

float
Kino_TermScorer_score(Scorer* scorer) {
    TermScorerChild *child;
    U32 freq;
    float score;
    unsigned char norm;

    child = (TermScorerChild*)scorer->child;

    freq    = child->freqs[child->pointer];
    if (freq < KINO_SCORE_CACHE_SIZE) {
        /* cache hit, so we don't need to recompute the whole score */
        score = child->score_cache[freq];
    }
    else {
        score = scorer->sim->tf(scorer->sim, freq) * child->weight_value;
    }

    /* normalize for field */
    norm = child->norms[child->doc];
    score *= scorer->sim->norm_decoder[norm];

    return score;
}

void
Kino_TermScorer_score_batch(Scorer *scorer, U32 start, U32 end,
                               HitCollector* hc) {
    TermScorerChild *child;
    U32              freq;
    unsigned char    norm;
    float            score;
    int              i;

    child = (TermScorerChild*)scorer->child;

    scorer->next(scorer);

    while(child->doc < end) {
        freq = child->freqs[child->pointer];
        if (freq < KINO_SCORE_CACHE_SIZE) {
            /* cache hit, so we don't need to recompute the whole score */
            score = child->score_cache[freq];
        }
        else {
            score = scorer->sim->tf(scorer->sim, freq) * child->weight_value;
        }

        /* normalize for field */
        norm = child->norms[child->doc];
        score *= scorer->sim->norm_decoder[norm];

        hc->collect(hc, child->doc, score);
        
        /* time for a refill? */
        if (++child->pointer >= child->pointer_max) {
            /* try to get more docs and freqs */
            child->pointer_max = child->term_docs->read(child->term_docs, 
                child->doc_nums_sv, child->freqs_sv, 1024);
            child->doc_nums = (U32*)SvPV_nolen(child->doc_nums_sv);
            child->freqs    = (U32*)SvPV_nolen(child->freqs_sv);

            /* bail if we didn't get any more docs */
            if (child->pointer_max != 0) {
                child->pointer = 0;
            }
            else {
                child->doc = KINO_TERM_SCORER_SENTINEL;
                /* TODO Lucene calls termDocs.close() here. */
                return;
            }
        }

        child->doc = child->doc_nums[ child->pointer ];
    }
}

U32 
Kino_TermScorer_doc(Scorer* scorer) {
    TermScorerChild *child = (TermScorerChild*)scorer->child;
    return child->doc;
}


__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::TermScorer - scorer for TermQuery

=head1 DESCRIPTION 

Subclass of Scorer which scores individual Terms.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut

