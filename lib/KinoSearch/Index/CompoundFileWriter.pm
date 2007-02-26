use strict;
use warnings;

package KinoSearch::Index::CompoundFileWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        invindex => undef,
        seg_info => undef,
        # members
        entries => {},
        merged  => 0,
    );
}

use KinoSearch::Util::CClass qw( to_kino );
use KinoSearch::Index::IndexFileNames qw( COMPOUND_FILE_FORMAT );

# Add a file to the list of files-to-merge.
sub add_file {
    my ( $self, $filename ) = @_;
    confess("filename '$filename' already added")
        if $self->{entries}{$filename};
    $self->{entries}{$filename} = 1;
}

# Write a compound file.
sub finish {
    my $self           = shift;
    my $folder         = $self->{invindex}->get_folder;
    my $seg_info       = $self->{seg_info};
    my @files_to_merge = keys %{ $self->{entries} };
    confess('no entries defined') unless @files_to_merge;

    # ensure that the file only gets written once
    confess('merge already performed') if $self->{merged};
    $self->{merged} = 1;

    # copy files, recording metadata as we go.
    my %sub_files;
    my %metadata = (
        sub_files => \%sub_files,
        format    => COMPOUND_FILE_FORMAT,
    );
    my $outstream
        = $folder->open_outstream( $seg_info->get_seg_name . '.cf' );
    for my $file (@files_to_merge) {
        my $instream = $folder->open_instream($file);
        my $offset   = $outstream->stell;
        $outstream->absorb($instream);
        my $len = $outstream->stell - $offset;
        $sub_files{$file} = { offset => $offset, 'length' => $len };
    }
    $outstream->sclose;

    # store metadata
    $seg_info->add_metadata( 'compound_file', \%metadata );
}

1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::CompoundFileWriter - Consolidate InvIndex files.

=head1 DESCRIPTION

CompoundFileWriter takes a list of pre-existing files and writes a new file
which combines them into one.  It writes a header containing filenames and
filepointers, then writes a data section containing file content.  The
original files are not deleted, so cleanup must be done externally.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
