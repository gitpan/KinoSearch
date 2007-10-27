use strict;
use warnings;

package KinoSearch::Search::Scorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj Exporter );

our %instance_vars = (
    # constructor params
    similarity => undef,
);

our @EXPORT_OK = qw( %collect_args );

our %collect_args = (
    collector    => undef,
    start        => 0,
    end          => 2**31,
    hits_per_seg => 2**31,
    seg_starts   => undef,
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
             (void)REFCOUNT_INC(self->sim);
             break;

    case 2:  retval = self->sim  == NULL
                ? newSV(0)
                : kobj_to_pobj(self->sim);
             break;

    END_SET_OR_GET_SWITCH
}

bool
next(self)
    kino_Scorer* self;
CODE:
    RETVAL = Kino_Scorer_Next(self);
OUTPUT: RETVAL


=begin comment

    $scorer->collect( 
        collector => $collector,
        start     => $start,
        end       => $end,
    );

Execute the scoring number crunching, accumulating results via the 
$collector.

=end comment
=cut

void
collect(self, ...)
    kino_Scorer *self;
PPCODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::Scorer::collect_args");
    kino_HitCollector *hc = (kino_HitCollector*)extract_obj(
        args_hash, SNL("collector"), "KinoSearch::Search::HitCollector");
    chy_u32_t start         = extract_uv(args_hash, SNL("start"));
    chy_u32_t end           = extract_uv(args_hash, SNL("end"));
    chy_u32_t hits_per_seg  = extract_uv(args_hash, SNL("hits_per_seg"));
    kino_VArray *seg_starts = (kino_VArray*)maybe_extract_obj(args_hash, 
        SNL("seg_starts"), "KinoSearch::Util::VArray");
    Kino_Scorer_Collect(self, hc, start, end, hits_per_seg, seg_starts);
}


bool
skip_to(self, target_doc_num)
    kino_Scorer* self;
    chy_u32_t target_doc_num;
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
