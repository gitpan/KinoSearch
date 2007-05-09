use strict;
use warnings;

package KinoSearch::Index::DocWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    invindex => undef,
    seg_info => undef,
    # members
    schema        => undef,
    fdata_stream  => undef,
    findex_stream => undef,
);

use Compress::Zlib qw( compress );
use KinoSearch::Util::StringHelper qw( utf8_flag_off );
use KinoSearch::Index::IndexFileNames qw( DOC_STORAGE_FORMAT );

sub init_instance {
    my $self     = shift;
    my $seg_name = $self->{seg_info}->get_seg_name;
    my $folder   = $self->{invindex}->get_folder;

    # extract schema
    $self->{schema} = $self->{invindex}->get_schema;

    # open an index stream and a data stream.
    $self->{findex_stream} = $folder->open_outstream("$seg_name.dsxtemp");
    $self->{fdata_stream}  = $folder->open_outstream("$seg_name.ds");
}

sub add_doc {
    my ( $self, $doc ) = @_;
    my $fdata_stream = $self->{fdata_stream};
    my $schema       = $self->{schema};
    my $seg_info     = $self->{seg_info};

    # only store fields marked as "stored"
    my @names_of_stored
        = grep { $schema->fetch_fspec($_)->stored } keys %$doc;

    # record the data stream's current file pointer in the index.
    my $start = $fdata_stream->stell;
    $self->{findex_stream}->lu_write( 'Q', $start );

    # add the number of stored fields in the doc
    $fdata_stream->lu_write( 'V', scalar @names_of_stored );

    # write field number and value for each stored field
    for (@names_of_stored) {
        my $field_spec = $schema->fetch_fspec($_);
        if ( $field_spec->compressed ) {
            utf8_flag_off( $doc->{$_} );
            $fdata_stream->lu_write( 'TT', $_, compress( $doc->{$_} ) );
        }
        else {
            $fdata_stream->lu_write( 'TT', $_, $doc->{$_} );
        }
    }

    # record the number of bytes taken up by the doc
    my $end = $fdata_stream->stell;
    my $len = $end - $start;
    $self->{findex_stream}->lu_write( 'Q', $len );
}

sub add_segment {
    my ( $self, $seg_reader, $doc_map ) = @_;
    my ( $findex_stream, $fdata_stream )
        = @{$self}{qw( findex_stream fdata_stream )};
    my $doc_reader = $seg_reader->get_doc_reader;

    my $max = $seg_reader->max_doc;
    return unless $max;
    $max -= 1;
    for my $orig ( 0 .. $max ) {
        # if the doc isn't deleted, copy it to the new seg
        next unless defined $doc_map->get($orig);

        # write pointer
        $findex_stream->lu_write( 'Q', $fdata_stream->stell );

        # retrieve a record
        my $record = $doc_reader->read_record($orig);
        my $len    = bytes::length($$record);
        $fdata_stream->lu_write( "a$len", $$record );
        $findex_stream->lu_write( 'Q',    $len );
    }
}

sub finish {
    my ( $self, $doc_remap ) = @_;
    my $folder   = $self->{invindex}->get_folder;
    my $seg_name = $self->{seg_info}->get_seg_name;

    $self->{fdata_stream}->sclose;
    $self->{findex_stream}->sclose;

    if ( defined $doc_remap ) {
        my $orig     = $folder->open_instream("$seg_name.dsxtemp");
        my $final    = $folder->open_outstream("$seg_name.dsx");
        my $max_doc  = $orig->slength / 16;
        my $contents = '\0' x ( $max_doc * 16 );
        for ( my $i = 0; $i < $max_doc; $i++ ) {
            my $new_doc = $doc_remap->get($i);
            $orig->read_byteso( $contents, $new_doc * 16, 16 );
        }
        $final->print($contents);
        $final->sclose;
        $orig->sclose;
    }
    else {
        $folder->rename_file( "$seg_name.dsxtemp", "$seg_name.dsx" );
    }

    # store metadata
    my %metadata = ( format => DOC_STORAGE_FORMAT, );
    $self->{seg_info}->add_metadata( 'doc_storage', \%metadata );

}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::DocWriter - Write stored documents to an InvIndex.

=head1 DESCRIPTION

DocWriter writes fields which are marked as stored to an InvIndex.  The
process may be lossy, as the document boost is not preserved in its original
form.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
