use strict;
use warnings;

package KinoSearch::Store::FileDes;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

sub new { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::FileDes

void
fdread(self, dest, dest_offset, len)
    kino_FileDes *self;
    char *dest;
    chy_u32_t dest_offset;
    chy_u32_t len;
PPCODE:
    Kino_FileDes_FDRead(self, dest, dest_offset, len);

void
fdwrite(self, buf, len)
    kino_FileDes *self;
    char *buf;
    chy_u32_t len;
PPCODE:
    Kino_FileDes_FDWrite(self, buf, len);

chy_u64_t
fdlength(self)
    kino_FileDes *self;
CODE:
    RETVAL = Kino_FileDes_FDLength(self);
OUTPUT: RETVAL

void
fdclose(self)
    kino_FileDes *self;
PPCODE:
    Kino_FileDes_FDClose(self);

=for comment

For testing purposes only.  Track number of FileDes objects in existence.

=cut

chy_i32_t
object_count()
CODE:
    RETVAL = kino_FileDes_object_count;
OUTPUT: RETVAL

=for comment

For testing purposes only.  Track number of FileDes objects in an open state.

=cut

chy_i32_t
open_count()
CODE:
    RETVAL = kino_FileDes_open_count;
OUTPUT: RETVAL

=for comment

For testing purposes only.  Used to help produce buffer alignment tests.

=cut

IV
_BUF_SIZE()
CODE:
   RETVAL = KINO_IO_STREAM_BUF_SIZE;
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::FileDes - Abstract file descriptor.

=head1 DESCRIPTION

Abstraction of a file descriptor, or perhaps more accurately a file stream a
la the c type FILE*.

InStream and OutStream define an interface by which other modules may write to
a FileDes.  FileDes implements a lower-level buffered read/write.  Subclasses
include FSFileDes for reading/writing to disk and RAMFileDes for
reading/writing to ram "files".

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

