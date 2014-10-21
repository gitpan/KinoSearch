package KinoSearch::Index::CompoundFileReader;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::InvIndex );    # !!

use KinoSearch::Store::InStream;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members / constructor params
    invindex => undef,
    seg_name => undef,
    # members
    instream => undef,
    entries  => undef,
);

sub init_instance {
    my $self = shift;
    my ( $seg_name, $invindex ) = @{$self}{ 'seg_name', 'invindex' };

    # read in names and lengths for all the "files" within the compound file
    my $instream = $self->{instream}
        = $invindex->open_instream("$seg_name.cfs");
    my $num_entries       = $instream->lu_read('V');
    my @offsets_and_names = $instream->lu_read( 'QT' x $num_entries );
    my $offset            = shift @offsets_and_names;
    my %entries;
    while (@offsets_and_names) {
        my $filename = shift @offsets_and_names;
        my $next_offset = shift @offsets_and_names || $instream->length;
        $entries{$filename} = {
            offset => $offset,
            len    => $next_offset - $offset,
        };
        $offset = $next_offset;
    }
    $self->{entries} = \%entries;
}

sub open_instream {
    my ( $self, $filename ) = @_;
    my $entry = $self->{entries}{$filename};
    croak("filename '$filename' is not accessible") unless defined $entry;
    open( my $duped_fh, '<&=', $self->{instream}->get_fh )
        or confess("Couldn't dupe filehandle: $!");
    return KinoSearch::Store::InStream->new( $duped_fh, $entry->{offset},
        $entry->{len} );
}

sub slurp_file {
    my ( $self, $filename ) = @_;
    my $instream = $self->open_instream($filename);
    my $contents
        = $instream->lu_read( 'a' . $self->{entries}{$filename}{len} );
    $instream->close;
    return $contents;
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::CompoundFileReader - read from a compound file

=head1 SYNOPSIS

    my $comp_file_reader = KinoSearch::Index::CompoundFileReader->new(
        invindex => $invindex,
        filename => "$seg_name.cfs",
    );
    my $instream = $comp_file_reader->open_instream("$seg_name.fnm");

=head1 DESCRIPTION

A CompoundFileReader provides access to the files contained within the
compound file format written by CompoundFileWriter.  The InStream objects it
spits out behave largely like InStreams opened against discrete files --
$instream->seek(0) seeks to the beginning of the sub-file, not the beginning
of the compound file.  

CompoundFileReader is a little unusual in that it subclasses
KinoSearch::Store::InvIndex, which is outside of the KinoSearch::Index::
package.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut

