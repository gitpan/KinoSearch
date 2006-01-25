package KinoSearch::Index::CompoundFileWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    invindex => undef,
    filename => undef,
    # members
    entries => {},
    merged  => 0,
);

# Add a file to the list of files-to-merge.
sub add_file {
    my ( $self, $filename ) = @_;
    croak("filename '$filename' already added")
        if $self->{entries}{$filename};
    $self->{entries}{$filename} = 1;
}

# Write a compound file.
sub finish {
    my $self           = shift;
    my $invindex       = $self->{invindex};
    my @files_to_merge = keys %{ $self->{entries} };
    croak('no entries defined') unless @files_to_merge;

    # ensure that the file only gets written once; open the outfile
    croak('merge already performed') if $self->{merged};
    $self->{merged} = 1;
    my $outstream = $invindex->open_outstream( $self->{filename} );

    # write number of files, plus data_offset placeholders
    my @to_write = map { ( 0, $_ ) } @files_to_merge;
    unshift @to_write, scalar @files_to_merge;
    my $template = 'V' . ( 'QT' x scalar @files_to_merge );
    $outstream->lu_write( $template, @to_write );

    # copy data
    my @data_offsets;
    my $out_fh = $outstream;
    for my $file (@files_to_merge) {
        push @data_offsets, $outstream->tell;
        my $instream = $invindex->open_instream($file);
        local $/ = \4096;
        print $outstream $_ while (<$instream>);
    }

    # rewrite number of files, plus real data offsets
    $outstream->seek(0);
    @to_write = map { ( shift @data_offsets, $_ ) } @files_to_merge;
    unshift @to_write, scalar @files_to_merge;
    $outstream->lu_write( $template, @to_write );

    $outstream->close;
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::CompoundFileWriter - consolidate invindex files

=head1 DESCRIPTION

CompoundFileWriter takes a list of pre-existing files and writes a new file
which combines them into one.  It writes a header containing filenames and
filepointers, then writes a data section containing file content.  The
original files are not deleted, so cleanup must be done externally.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut
