package KinoSearch::Search::PhraseScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    weight          => undef,
    term_docs       => [],
    phrase_offsets  => [],
    norms_reader    => undef,
    slop            => 0,
);

sub new {
    my $self = shift->SUPER::new;
    verify_args(\%instance_vars, @_);
    my %args = (%instance_vars, @_);

    $self->_init_child;

    $self->_set_norms( $args{norms_reader}->get_bytes );
    $self->set_similarity( $args{similarity} );
    $self->_set_weight_value( $args{weight}->get_value );
    confess("Sloppy phrase matching not yet implemented")
        unless $args{slop} == 0; # TODO -- enable slop.
    $self->_set_slop( $args{slop} );

    # sort terms by ascending frequency
    confess("positions count doesn't match term count") 
        unless $#{ $args{term_docs} } == $#{ $args{phrase_offsets} };
    my @by_size = sort { $a->[0]->get_doc_freq <=> $b->[0]->get_doc_freq }
        map { [ $args{term_docs}[$_], $args{phrase_offsets}[$_] ] }
        0 .. $#{ $args{term_docs} };
    my @term_docs = map { $_->[0] } @by_size;
    my @phrase_offsets = map { $_->[1] } @by_size;
    $self->_init_elements(\@term_docs, \@phrase_offsets);

    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::PhraseScorer

SV*
_phrase_scorer_set_or_get(obj, ...)
    Scorer *obj;
PREINIT:
    PhraseScorerChild *child;
ALIAS:
    _set_slop = 1
    _get_slop = 2
    _set_weight_value = 3
    _get_weight_value = 4
    _set_norms        = 5
    _get_norms        = 6
CODE:
{
    child = (PhraseScorerChild*)obj->child;

    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        Kino_confess("usage: $scorer->set_xxxxxx($val)");

    switch (ix) {

    case 1:  child->slop = SvIV( ST(1) );
             /* fall through */
    case 2:  RETVAL = newSViv(child->slop);
             break;

    case 3:  child->weight_value = SvNV( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVnv(child->weight_value);
             break;

    case 5:  if (child->norms_sv != NULL) 
                SvREFCNT_dec(child->norms_sv);
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
    case 6:  RETVAL = newSVsv(child->norms_sv);
             break;

    }
}
OUTPUT: RETVAL

void
_init_elements(obj, term_docs_av, phrase_offsets_av) 
    Scorer *obj;
    AV     *term_docs_av;
    AV     *phrase_offsets_av;
PREINIT:
    PhraseScorerChild *child;
    I32                i;
    SV               **sv_ptr;
    IV                 tmp;
PPCODE:
{
    child = (PhraseScorerChild*)obj->child;

    SvREFCNT_inc(term_docs_av);
    child->term_docs_av = term_docs_av;

    child->num_elements = av_len(term_docs_av) + 1;
    Kino_New(0, child->term_docs, child->num_elements, TermDocs*);
    Kino_New(0, child->phrase_offsets, child->num_elements, U32);
    
    /* create an array of TermDocs* */
    for(i = 0; i < child->num_elements; i++) {
        sv_ptr = av_fetch(term_docs_av, i, 0);
        tmp                 = SvIV((SV*)SvRV( *sv_ptr ));
        child->term_docs[i] = INT2PTR(TermDocs*, tmp);
        sv_ptr = av_fetch(phrase_offsets_av, i, 0);
        child->phrase_offsets[i] = SvIV( *sv_ptr );
    }
}

void
_init_child(obj)
    Scorer *obj;
PPCODE:
    Kino_PhraseScorer_init_child(obj);

void
DESTROY(obj)
    Scorer *obj;
PPCODE:
    Kino_PhraseScorer_destroy(obj);

__H__

#ifndef H_KINO_PHRASE_SCORER
#define H_KINO_PHRASE_SCORER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchIndexTermDocs.h"
#include "KinoSearchSearchScorer.h"
#include "KinoSearchUtilMemManager.h"

typedef struct phrasescorerchild {
    U32             doc;
    U32             slop;
    U32             num_elements;
    TermDocs      **term_docs;
    U32            *phrase_offsets;
    float           phrase_freq;
    float           weight_value;
    U32             first_time;
    unsigned char  *norms;
    SV             *anchor_set;
    float         (*calc_phrase_freq)(Scorer*);
    SV             *norms_sv;
    AV             *term_docs_av;
} PhraseScorerChild;

void  Kino_PhraseScorer_init_child(Scorer*);
bool  Kino_PhraseScorer_next(Scorer*);
float Kino_PhraseScorer_calc_phrase_freq(Scorer*);
U32   Kino_PhraseScorer_doc(Scorer*);
float Kino_PhraseScorer_score(Scorer*);

#endif /* include guard */



__C__

#include "KinoSearchSearchPhraseScorer.h"

void
Kino_PhraseScorer_init_child(Scorer *scorer) {
    PhraseScorerChild *child;

    /* allocate */
    Kino_New(0, child, 1, PhraseScorerChild);
    scorer->child = child;
    child->anchor_set      = newSV(0);

    /* init */
    child->doc             = 0xFFFFFFFF;
    child->slop            = 0;
    child->first_time      = 1;
    child->phrase_freq     = 0.0;
    child->norms           = NULL;
    child->phrase_offsets  = NULL;
    child->term_docs_av    = NULL;
    child->norms_sv        = NULL;


    /* define abstract methods */
    scorer->next            = Kino_PhraseScorer_next;
    scorer->score           = Kino_PhraseScorer_score;
    scorer->doc             = Kino_PhraseScorer_doc;
    child->calc_phrase_freq = Kino_PhraseScorer_calc_phrase_freq;
}

bool
Kino_PhraseScorer_next(Scorer *scorer) {
    PhraseScorerChild *child;
    TermDocs         **term_docs;
    U32                candidate;
    U32                i;

    child = (PhraseScorerChild*)scorer->child;
    term_docs = child->term_docs;
    
    child->phrase_freq = 0.0;
    child->doc = 0xFFFFFFFF; 

    if (child->first_time) {
        child->first_time = 0;
        /* advance all except the first term_docs */
        for (i = 1; i < child->num_elements; i++) {
            if ( !term_docs[i]->next(term_docs[i]) )
                return 0;
        }
    }
    
    /* seed the search */
    if ( !term_docs[0]->next(term_docs[0]) )
        return 0;
    candidate = term_docs[0]->doc;

    /* find a doc which contains all the terms */
    FIND_COMMON_DOC:
    while (1) {
        for (i = 0; i < child->num_elements; i++) {
            while (term_docs[i]->doc < candidate) {
                if ( !term_docs[i]->next(term_docs[i]) )
                    return 0;
            }
            if (term_docs[i]->doc > candidate) {
                candidate = term_docs[i]->doc;
            }
        }
        for (i = 0; i < child->num_elements; i++) {
            if (term_docs[i]->doc != candidate) {
                goto FIND_COMMON_DOC;
            }
        }
        break; /* success! */
    }

    /* if the terms don't actually form a phrase, skip to the next doc */
    child->phrase_freq = child->calc_phrase_freq(scorer);
    if (child->phrase_freq == 0.0)
        return scorer->next(scorer);

    /* success! */
    child->doc  = candidate;
    return 1;
}

float
Kino_PhraseScorer_calc_phrase_freq(Scorer *scorer) {
    U32               *phrase_offsets;
    PhraseScorerChild *child;
    U32               *anchors;
    U32               *anchors_start;
    U32               *anchors_end;
    U32               *new_anchors;
    U32               *candidates;
    U32               *candidates_end;
    U32                target;
    U32                freq;
    U32                phrase_offset;
    U32                i;
    STRLEN             len;

    child = (PhraseScorerChild*)scorer->child;

    /* create an anchor set */
    sv_setsv(child->anchor_set, child->term_docs[0]->positions);
    anchors_start = (U32*)SvPVX(child->anchor_set);
    anchors       = anchors_start;
    anchors_end   = (U32*)SvEND(child->anchor_set);
    phrase_offset = child->phrase_offsets[0];
    while(anchors < anchors_end) {
        *anchors++ -= phrase_offset;
    }

    /* match the positions of other terms against the anchor set */
    for (i = 1; i < child->num_elements; i++) {
        phrase_offset = child->phrase_offsets[i];

        anchors     = anchors_start;
        new_anchors = anchors_start;
        anchors_end = (U32*)SvEND(child->anchor_set);
        new_anchors = anchors;

        candidates     = (U32*)SvPVX(child->term_docs[i]->positions);
        candidates_end = (U32*)SvEND(child->term_docs[i]->positions);

        while (anchors < anchors_end) {
            target = *candidates - phrase_offset;
            while (anchors < anchors_end && *anchors < target) {
                anchors++;
            }
            if (anchors == anchors_end)
                break;

            target = *anchors + phrase_offset;
            while (candidates < candidates_end && *candidates < target) {
                candidates++;
            }
            if (candidates == candidates_end)
                break;
            if (*candidates == *anchors + phrase_offset) {
                /* the anchor has made it through another elimination round */
                *new_anchors = *anchors;
                new_anchors++;
            }
            anchors++;
        }

        /* winnow down the size of the anchor set */
        len = (char*)new_anchors - (char*)anchors_start;
        SvCUR_set(child->anchor_set, len);
    }

    /* the number of anchors left is the phrase freq */
    len = SvCUR(child->anchor_set);
    return (float) len / sizeof(U32);
}

U32
Kino_PhraseScorer_doc(Scorer *scorer) {
    PhraseScorerChild* child = (PhraseScorerChild*)scorer->child;
    return child->doc;
}

float
Kino_PhraseScorer_score(Scorer *scorer) {
    PhraseScorerChild* child;
    float              score;
    unsigned char      norm;
    
    child = (PhraseScorerChild*)scorer->child;

    /* calculate raw score */
    score =  scorer->sim->tf(scorer->sim, child->phrase_freq) 
             * child->weight_value;

    /* normalize */
    norm   = child->norms[ child->doc ];
    score *= scorer->sim->norm_decoder[norm];

    return score;
}

void
Kino_PhraseScorer_destroy(Scorer *scorer) {
    PhraseScorerChild *child;
    
    child = (PhraseScorerChild*)scorer->child;

    if (child->term_docs != NULL)
        Kino_Safefree(child->term_docs);
    if (child->phrase_offsets != NULL)
        Kino_Safefree(child->phrase_offsets);
    if (child->norms_sv != NULL)
        SvREFCNT_dec(child->norms_sv);
    if (child->term_docs_av != NULL)
        SvREFCNT_dec((SV*)child->term_docs_av);

    SvREFCNT_dec(child->anchor_set);

    Kino_Safefree(child);
    Kino_Scorer_destroy(scorer);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::PhraseScorer - scorer for PhraseQuery

=head1 DESCRIPTION 

Score phrases.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut
