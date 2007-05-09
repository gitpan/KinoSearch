use strict;
use warnings;

package KinoSearch::Util::Stepper;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::Stepper

void
read_record(self, instream)
    kino_Stepper *self;
    kino_InStream  *instream;
PPCODE:
    Kino_Stepper_Read_Record(self, instream);

void
dump(self, instream)
    kino_Stepper   *self;
    kino_InStream  *instream;
PPCODE:
    Kino_Stepper_Dump(self, instream);

void
dump_to_file(self, instream, outstream)
    kino_Stepper   *self;
    kino_InStream  *instream;
    kino_OutStream *outstream;
PPCODE:
    Kino_Stepper_Dump_To_File(self, instream, outstream);

__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Util::Stepper - Abstract Encoder/Decoder.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


