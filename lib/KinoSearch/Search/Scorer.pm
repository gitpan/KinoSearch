package KinoSearch::Search::Scorer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass Exporter );
our @EXPORT_OK = qw( %score_batch_args );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    similarity => undef,
);

sub new {
    my $class = shift;
    verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    $class = ref($class) || $class;
    my $self = _construct_parent($class);

    if ( defined $args{similarity} ) {
        $self->set_similarity( $args{similarity} );
    }

    return $self;
}

our %score_batch_args = (
    hit_collector => undef,
    start         => 0,
    end           => 2**31,
);

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
    Scorer *scorer;
PPCODE:
    scorer   = Kino_Scorer_new();
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)scorer);
    XSRETURN(1);

SV*
_scorer_set_or_get(scorer, ...)
    Scorer *scorer;
ALIAS:
    set_similarity = 1
    get_similarity = 2
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $term_info->set_xxxxxx($val)");

    switch (ix) {

    case 1:  SvREFCNT_dec(scorer->similarity_sv);
             scorer->similarity_sv = newSVsv( ST(1) );
             Kino_extract_struct( scorer->similarity_sv, scorer->sim, 
                Similarity*, "KinoSearch::Search::Similarity" );
             /* fall through */
    case 2:  RETVAL = newSVsv(scorer->similarity_sv);
             break;
    }
}
OUTPUT: RETVAL


=begin comment

    my $score = $scorer->score;

Calculate and return a score for the scorer's current document.

=end comment
=cut

float
score(scorer)
    Scorer* scorer;
CODE:
    RETVAL = scorer->score(scorer);
OUTPUT: RETVAL


=begin comment

    my $valid_state = $scorer->next;

Move the internal state of the scorer to the next document.  Return false when
there are no more documents to score.

=end comment
=cut

bool
next(scorer)
    Scorer* scorer;
CODE:
    RETVAL = scorer->next(scorer);
OUTPUT: RETVAL


=begin comment

    $scorer->score_batch( 
        hit_collector => $collector,
        start         => $start,
        end           => $end,
    );

Execute the scoring number crunching, accumulating results via the 
$hit_collector.

TODO: Doesn't actually pay any attention to start/end at present.

=end comment
=cut

void
score_batch(scorer, ...)
    Scorer       *scorer;
PREINIT:
    HV           *args_hash;
    U32           start, end;
    HitCollector *hc;
PPCODE:
    /* process hash-style params */
    Kino_Verify_build_args_hash(args_hash, 
        "KinoSearch::Search::Scorer::score_batch_args", 1);
    Kino_extract_struct_from_hv(args_hash, hc, "hit_collector", 13, 
        HitCollector*, "KinoSearch::Search::HitCollector");
    start = (U32)SvUV( Kino_Verify_extract_arg(args_hash, "start", 5) );
    end   = (U32)SvUV( Kino_Verify_extract_arg(args_hash, "end", 3) );

    /* execute scoring loop */
    while (scorer->next(scorer)) {
        hc->collect( hc, scorer->doc(scorer), scorer->score(scorer) );
    }


=begin comment

Not implemented yet.

=end comment
=cut

bool
skip_to(scorer, target_doc_num)
    Scorer* scorer;
    U32     target_doc_num;
CODE:
    RETVAL = scorer->skip_to(scorer, target_doc_num);
OUTPUT: RETVAL


void
DESTROY(scorer)
    Scorer *scorer;
PPCODE:
    Kino_Scorer_destroy(scorer);

    
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
    scorer->similarity_sv = &PL_sv_undef;

    return scorer;
}

float
Kino_Scorer_score_death(Scorer* scorer) {
    Kino_confess("scorer->score must be defined in a subclass");
    return 1.0;
}

bool
Kino_Scorer_next_death(Scorer* scorer) {
    Kino_confess("scorer->next must be defined in a subclass");
    return 1;
}

U32
Kino_Scorer_doc_death(Scorer* scorer) {
    Kino_confess("scorer->doc must be defined in a subclass");
    return 1;
}

bool
Kino_Scorer_skip_to_death(Scorer* scorer, U32 target_doc_num) {
    Kino_confess("scorer->skip_to must be defined in a subclass");
    return 1;
}

void
Kino_Scorer_destroy(Scorer* scorer) {
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

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut
