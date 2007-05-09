use strict;
use warnings;

package KinoSearch::Search::MatchFieldScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = (
    # inherited constructor params
    similarity => undef,

    # constructor params
    weight     => undef,
    sort_cache => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::MatchFieldScorer


kino_MatchFieldScorer*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::MatchFieldScorer::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(args_hash,
        SNL("similarity"), "KinoSearch::Search::Similarity");
    kino_IntMap *sort_cache = (kino_IntMap*)extract_obj(args_hash,
        SNL("sort_cache"), "KinoSearch::Util::IntMap");
    SV *weight_ref = extract_sv(args_hash, SNL("weight") );

    /* create object */
    RETVAL = kino_MatchFieldScorer_new(sim, sort_cache, newSVsv(weight_ref));
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::MatchFieldScorer - Scorer for MatchFieldQuery.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

