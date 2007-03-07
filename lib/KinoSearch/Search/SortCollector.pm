use strict;
use warnings;

package KinoSearch::Search::SortCollector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::TopDocCollector );

BEGIN {
    __PACKAGE__->init_instance_vars(
        collator => undef,
        size     => undef,
    );
}
our %instance_vars;

use KinoSearch::Search::SortedHitQueue;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::SortCollector

kino_SortCollector*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::SortCollector::instance_vars");
    kino_u32_t size = extract_uv(args_hash, SNL("size"));
    kino_FieldDocCollator *collator = extract_obj(args_hash, SNL("collator"),
        "KinoSearch::Search::FieldDocCollator");
    RETVAL = kino_SortColl_new(collator, size);;
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::SortCollector - Sorting HitCollector.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


