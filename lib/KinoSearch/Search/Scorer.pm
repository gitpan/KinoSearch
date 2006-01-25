package KinoSearch::Search::Scorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    similarity => undef,
);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return $class->_construct_parent;
}

=begin comment

    $scorer->score_batch( 
        hit_collector => $collector,
        start         => $start,
        end           => $end,
    );

Execute the scoring number crunching, accumulating results via the 
$hit_collector.

=end comment
=cut

my %score_batch_args = (
    hit_collector => undef,
    start         => 0,
    end           => 2**31,
);

sub score_batch {
    my $self = shift;
    verify_args( \%score_batch_args, @_ );
    my %args = ( %score_batch_args, @_ );
    confess("param 'hit_collector' isn't a KinoSearch::Search::HitCollector")
        unless a_isa_b( $args{hit_collector},
        'KinoSearch::Search::HitCollector' );
    

    $self->do_score_batch(%args);
}

sub do_score_batch { 
    my ( $self, %args ) = @_;
    _do_score_batch( $self, @args{qw( start end hit_collector )} );
    # TODO in Lucene, this method returns true if any docs are processed
}

=begin comment

    my $explanation = $scorer->explain($doc_num);

Provide an Explanation for how this scorer rates a given doc.

=end comment
=cut

sub explain { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::Scorer

void
_construct_parent(class)
    char *class;
PREINIT:
    Scorer *obj;
PPCODE:
    obj   = Kino_Scorer_new();
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)obj);
    XSRETURN(1);

SV*
_scorer_set_or_get(obj, ...)
    Scorer *obj;
ALIAS:
    set_similarity = 1
    get_similarity = 2
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $term_info->set_xxxxxx($val)");

    switch (ix) {

    case 1:  if (obj->similarity_sv != NULL)
                SvREFCNT_dec(obj->similarity_sv);
             obj->similarity_sv = newSVsv( ST(1) );
             Kino_extract_struct( obj->similarity_sv, obj->sim, 
                Similarity*, "KinoSearch::Search::Similarity" );
             /* fall through */
    case 2:  RETVAL = newSVsv(obj->similarity_sv);
             break;
    }
}
OUTPUT: RETVAL

=begin comment

    my $score = $scorer->score;

Calculate and return a score for the scorer's current document.

Must be implemented by assigning a valid function for the C
pointer-to-function scorer->score.

=end comment
=cut


float
score(obj)
    Scorer* obj;
CODE:
    RETVAL = obj->score(obj);
OUTPUT: RETVAL

void
_do_score_batch(obj, start, end, hc)
    Scorer       *obj;
    U32           start;
    U32           end;
    HitCollector *hc;
PREINIT:
    U32           doc;
PPCODE:
    while (obj->next(obj)) {
        hc->collect( hc, obj->score(obj), obj->doc(obj) );
    }

=begin comment

    my $valid_state = $scorer->next;

Move the internal state of the scorer to the next document.  Return false when
there are no more documents to score.

Must be implemented by assigning a valid function for the C
pointer-to-function scorer->next.

=end comment
=cut

bool
next(obj)
    Scorer* obj;
CODE:
    RETVAL = obj->next(obj);
OUTPUT: RETVAL


=begin comment

Not implemented yet.

=end comment
=cut

bool
skip_to(obj, target_doc_num)
    Scorer* obj;
    U32     target_doc_num;
CODE:
    RETVAL = obj->skip_to(obj, target_doc_num);
OUTPUT: RETVAL

void
DESTROY(obj)
    Scorer *obj;
PPCODE:
    Kino_Scorer_destroy(obj);

    
__H__

#ifndef H_KINO_SCORER
#define H_KINO_SCORER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchSearchSimilarity.h"
#include "KinoSearchUtilMemManager.h"
#include "KinoSearchUtilCarp.h"

typedef struct scorer {
    void       *child;
    Similarity *sim;
    float     (*score)(struct scorer*);
    bool      (*next)(struct scorer*);
    U32       (*doc)(struct scorer*);
    bool      (*skip_to)(struct scorer*, U32);
    SV         *similarity_sv;
} Scorer;

Scorer* Kino_Scorer_new();
float Kino_Scorer_score_death(Scorer*);
bool  Kino_Scorer_next_death(Scorer*);
U32   Kino_Scorer_doc_death(Scorer*);
bool  Kino_Scorer_skip_to_death(Scorer*, U32);
void  Kino_Scorer_destroy(Scorer*);

#endif /* include guard */

__C__

#include "KinoSearchSearchScorer.h"

Scorer*
Kino_Scorer_new() {
    Scorer* scorer;

    Kino_New(0, scorer, 1, Scorer);
    scorer->child         = NULL;
    scorer->sim           = NULL;
    scorer->next          = Kino_Scorer_next_death;
    scorer->score         = Kino_Scorer_score_death;
    scorer->skip_to       = Kino_Scorer_skip_to_death;
    scorer->similarity_sv = NULL;
}

float
Kino_Scorer_score_death(Scorer* scorer) {
    Kino_confess("scorer->score must be defined in a subclass");
}

bool
Kino_Scorer_next_death(Scorer* scorer) {
    Kino_confess("scorer->next must be defined in a subclass");
}

U32
Kino_Scorer_doc_death(Scorer* scorer) {
    Kino_confess("scorer->doc must be defined in a subclass");
}

bool
Kino_Scorer_skip_to_death(Scorer* scorer, U32 target_doc_num) {
    Kino_confess("scorer->skip_to must be defined in a subclass");
}

void
Kino_Scorer_destroy(Scorer* scorer) {
    if (scorer->similarity_sv != NULL)
        SvREFCNT_dec(scorer->similarity_sv);
        Kino_Safefree(scorer);
}


__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::Scorer - score documents against a Query

=head1 DESCRIPTION 

Abstract base class for scorers.

Scorers iterate through a list of documents, producing score/doc_num pairs for
further processing, typically by a HitCollector.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05.

=end devdocs
=cut
