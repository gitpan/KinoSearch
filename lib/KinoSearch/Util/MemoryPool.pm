use strict;
use warnings;

package KinoSearch::Util::MemoryPool;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::MemoryPool

chy_bool_t
run_tests(...)
CODE:
    CHY_UNUSED_VAR(items);
    RETVAL = kino_MemPool_run_tests();
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Util::MemoryPool - Special-purpose memory allocator.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


