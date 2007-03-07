use strict;
use warnings;

package KinoSearch::Search::Scorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj Exporter );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        similarity => undef,
    );
}

our @EXPORT_OK = qw( %score_batch_args );

our %score_batch_args = (
    hit_collector => undef,
    start         => 0,
    end           => 2**31,
    prune_factor  => 2**31,
    seg_starts    => undef,
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
_scorer_set_or_get(self, ...)
    kino_Scorer *self;
ALIAS:
    set_similarity = 1
    get_similarity = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  REFCOUNT_DEC(self->sim);
             EXTRACT_STRUCT( ST(1), self->sim, kino_Similarity*, 
                "KinoSearch::Search::Similarity" );
             REFCOUNT_INC(self->sim);
             break;

    case 2:  retval = self->sim  == NULL
                ? newSV(0)
                : kobj_to_pobj(self->sim);
             break;

    END_SET_OR_GET_SWITCH
}


float
score(self)
    kino_Scorer* self;
CODE:
    RETVAL = Kino_Scorer_Score(self);
OUTPUT: RETVAL


bool
next(self)
    kino_Scorer* self;
CODE:
    RETVAL = Kino_Scorer_Next(self);
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
score_batch(self, ...)
    kino_Scorer *self;
PPCODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::Scorer::score_batch_args");
    kino_HitCollector *hc = (kino_HitCollector*)extract_obj(
        args_hash, SNL("hit_collector"), "KinoSearch::Search::HitCollector");
    kino_u32_t start        = extract_uv(args_hash, SNL("start"));
    kino_u32_t end          = extract_uv(args_hash, SNL("end"));
    kino_u32_t prune_factor = extract_uv(args_hash, SNL("prune_factor"));
    kino_VArray *seg_starts = (kino_VArray*)maybe_extract_obj(args_hash, 
        SNL("seg_starts"), "KinoSearch::Util::VArray");
    Kino_Scorer_Score_Batch(self, hc, start, end, prune_factor, seg_starts);
}


bool
skip_to(self, target_doc_num)
    kino_Scorer* self;
    kino_u32_t target_doc_num;
CODE:
    RETVAL = Kino_Scorer_Skip_To(self, target_doc_num);
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::Scorer - Score documents against a Query.

=head1 DESCRIPTION 

Abstract base class for scorers.

Scorers iterate through a list of documents, producing score/doc_num pairs for
further processing, typically by a HitCollector.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
