use strict;
use warnings;

package KinoSearch::Search::BooleanScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

BEGIN { __PACKAGE__->init_instance_vars() }
our %instance_vars;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::BooleanScorer

kino_BooleanScorer*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::BooleanScorer::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(
        args_hash, SNL("similarity"), "KinoSearch::Search::Similarity");

    /* create object */
    RETVAL = kino_BoolScorer_new(sim);
}
OUTPUT: RETVAL

void 
add_subscorer(self, subscorer, occur)
    kino_BooleanScorer *self;
    kino_Scorer *subscorer;
    char *occur;
PPCODE:
    Kino_BoolScorer_Add_Subscorer(self, subscorer, occur);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::BooleanScorer - Scorer for BooleanQuery.

=head1 DESCRIPTION 

Implementation of Scorer for BooleanQuery.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
