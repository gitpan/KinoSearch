use strict;
use warnings;

use KinoSearch;
package KinoSearch::Util::Debug;
use base qw( Exporter );

our @EXPORT_OK = qw(
    DEBUG
    DEBUG_PRINT
    DEBUG_ENABLED
    ASSERT
    set_env_cache
);

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::Debug

void
DEBUG_PRINT(message)
    char *message;
PPCODE:
    KINO_DEBUG_PRINT("%s", message);

void
DEBUG(message)
    char *message;
PPCODE:
    KINO_DEBUG("%s", message);

chy_bool_t
DEBUG_ENABLED()
CODE:
    RETVAL = KINO_DEBUG_ENABLED;
OUTPUT: RETVAL

void
set_env_cache(str)
    char *str;
PPCODE:
    kino_Debug_set_env_cache(str);

void
ASSERT(maybe)
    int maybe;
PPCODE:
    KINO_ASSERT(maybe, "XS ASSERT binding test");

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::Debug - Interface for C-level debug utils.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
