use strict;
use warnings;

package KinoSearch::Search::ANDORScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = (
    # params
    similarity => undef,
    and_scorer => undef,
    or_scorer  => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::ANDORScorer

kino_ANDORScorer*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::ANDORScorer::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(
        args_hash, SNL("similarity"), "KinoSearch::Search::Similarity");
    kino_Scorer *and_scorer = (kino_Scorer*)extract_obj(
        args_hash, SNL("and_scorer"), "KinoSearch::Search::Scorer");
    kino_Scorer *or_scorer = (kino_Scorer*)extract_obj(
        args_hash, SNL("or_scorer"), "KinoSearch::Search::Scorer");

    /* create object */
    RETVAL = kino_ANDORScorer_new(sim, and_scorer, or_scorer);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::ANDORScorer - Intersect required and optional scorers.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
