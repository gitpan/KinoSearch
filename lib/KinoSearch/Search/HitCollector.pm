use strict;
use warnings;

package KinoSearch::Search::HitCollector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

sub new { confess("Not accessible from Perl-space") }

our %new_offs_coll_defaults = (
    hit_collector => undef,
    offset        => undef,
);

our %new_bit_coll_defaults = ( bit_vector => undef, );

our %new_filt_coll_defaults = (
    hit_collector => undef,
    filter_bits   => undef,
);

our %new_range_coll_defaults = (
    hit_collector => undef,
    sort_cache    => undef,
    lower_bound   => undef,
    upper_bound   => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitCollector

kino_HitCollector*
new_offset_coll(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::HitCollector::new_offs_coll_defaults");
    kino_HitCollector *inner_coll = (kino_HitCollector*)extract_obj(
        args_hash, SNL("hit_collector"), "KinoSearch::Search::HitCollector");
    kino_u32_t offset = extract_uv(args_hash, SNL("offset"));

    /* create object */
    RETVAL = kino_HC_new_offset_coll(inner_coll, offset);
}
OUTPUT: RETVAL

kino_HitCollector*
new_bit_coll(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::HitCollector::new_bit_coll_defaults");
    kino_BitVector *bit_vec = (kino_BitVector*)extract_obj(args_hash, 
        SNL("bit_vector"), "KinoSearch::Util::BitVector");

    /* create object */
    RETVAL = kino_HC_new_bit_coll(bit_vec);
}
OUTPUT: RETVAL

kino_HitCollector*
new_filt_coll(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::HitCollector::new_filt_coll_defaults");
    kino_HitCollector *inner_coll = (kino_HitCollector*)extract_obj(
        args_hash, SNL("hit_collector"), "KinoSearch::Search::HitCollector");
    kino_BitVector *filt_bits = (kino_BitVector*)extract_obj(
        args_hash, SNL("filter_bits"), "KinoSearch::Util::BitVector");

    /* create object */
    RETVAL = kino_HC_new_filt_coll(inner_coll, filt_bits);
}
OUTPUT: RETVAL

kino_HitCollector*
new_range_coll(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::HitCollector::new_range_coll_defaults");
    kino_HitCollector *inner_coll = (kino_HitCollector*)extract_obj(
        args_hash, SNL("hit_collector"), "KinoSearch::Search::HitCollector");
    kino_IntMap *sort_cache = (kino_IntMap*)extract_obj(
        args_hash, SNL("sort_cache"), "KinoSearch::Util::IntMap");
    kino_i32_t lower_bound = extract_iv(args_hash, SNL("lower_bound"));
    kino_i32_t upper_bound = extract_iv(args_hash, SNL("upper_bound"));

    /* create object */
    RETVAL = kino_HC_new_range_coll(inner_coll, sort_cache, lower_bound,
        upper_bound);
}
OUTPUT: RETVAL

void
collect(self, doc_num, score)
    kino_HitCollector *self;
    kino_u32_t    doc_num;
    float         score;
PPCODE:
    self->collect(self, doc_num, score);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::HitCollector - Process doc/score pairs.

=head1 DESCRIPTION

A Scorer spits out raw doc_num/score pairs; a HitCollector decides what to do
with them, based on the collector->collect method.

=head1 METHODS

=head2 collect

    $hit_collector->collect( $doc_num, $score );

Abstract method.

Process a doc_num/score combination.  In production, this method should not be
called from Perl, as collecting hits is an extremely data-intensive operation.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


