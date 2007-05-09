use strict;
use warnings;

package KinoSearch::Search::ANDScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = (
    # params
    similarity => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::ANDScorer

kino_ANDScorer*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::ANDScorer::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(
        args_hash, SNL("similarity"), "KinoSearch::Search::Similarity");

    /* create object */
    RETVAL = kino_ANDScorer_new(sim);
}
OUTPUT: RETVAL

void 
add_subscorer(self, subscorer)
    kino_ANDScorer *self;
    kino_Scorer *subscorer;
PPCODE:
    Kino_ANDScorer_Add_Subscorer(self, subscorer);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::ANDScorer - Intersect multiple required Scorers.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
