use strict;
use warnings;

package KinoSearch::Search::SortedHitQueue;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitQueue );

BEGIN { __PACKAGE__->init_instance_vars() }
our %instance_vars;

use KinoSearch::Search::FieldDoc;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::SortedHitQueue

kino_SortedHitQueue*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::SortedHitQueue::instance_vars");
    kino_u32_t max_size = extract_uv(args_hash, SNL("max_size"));

    /* create object */
    RETVAL = kino_SortedHitQ_new(max_size);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::SortedHitQueue - Track highest sorting docs.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
