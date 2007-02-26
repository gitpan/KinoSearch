use strict;
use warnings;

package KinoSearch::Index::CompoundFileReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Folder );    # !!

BEGIN {
    __PACKAGE__->init_instance_vars(
        # members / constructor params
        invindex => undef,
        seg_info => undef,
    );
}
our %instance_vars;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::CompoundFileReader

kino_CompoundFileReader*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::CompoundFileReader::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
         args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");

    RETVAL = kino_CFReader_new(invindex, seg_info);
}
OUTPUT: RETVAL



__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::CompoundFileReader - Read from a compound file.

=head1 SYNOPSIS

    my $comp_file_reader = KinoSearch::Index::CompoundFileReader->new(
        invindex => $invindex,
        filename => "$seg_name.cf",
    );
    my $instream = $comp_file_reader->open_instream("$seg_name.fnm");

=head1 DESCRIPTION

A CompoundFileReader provides access to the files contained within the
compound file format written by CompoundFileWriter.  The InStream objects it
spits out behave largely like InStreams opened against discrete files --
$instream->sseek(0) seeks to the beginning of the sub-file, not the beginning
of the compound file.  

Each of the InStreams spawned maintains its own memory buffer; however, they
all share a single filehandle.  This allows KinoSearch to get around the
limitations that many operating systems place on the number of available
filehandles.

CompoundFileReader is a little unusual in that it subclasses
KinoSearch::Store::Folder, which is outside of the KinoSearch::Index::
package.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

