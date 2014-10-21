use strict;
use warnings;

package KSx::Index::ByteBufDocWriter;
use base qw( KinoSearch::Index::DataWriter );
use Carp;
use Scalar::Util qw( blessed );
use bytes;
no bytes;

# Inside-out member vars.
our %field;
our %width;
our %outstream;

sub new {
    my ( $either, %args ) = @_;
    my $width = delete $args{width};
    my $field = delete $args{field};
    my $self  = $either->SUPER::new(%args);
    confess("Missing required param 'width'") unless defined $width;
    confess("Missing required param 'field'") unless defined $field;
    if ( $width < 1 ) { confess("'width' must be at least 1") }
    $field{$$self} = $field;
    $width{$$self} = $width;
    return $self;
}

sub _lazy_init {
    my $self = shift;

    # Get outstream.  Skip past non-doc #0.
    my $folder    = $self->get_folder;
    my $filename  = $self->get_segment->get_name . "/bytebufdocs.dat";
    my $outstream = $outstream{$$self} = $folder->open_out($filename)
        or confess KinoSearch->error;
    my $nulls = "\0" x $width{$$self};
    $outstream->print($nulls);

    return $outstream;
}

sub add_inverted_doc {
    my ( $self, %args ) = @_;
    my $outstream = $outstream{$$self} || _lazy_init($self);
    my $fields    = $args{inverter}->get_doc->get_fields;
    my $width     = $width{$$self};
    my $field     = $field{$$self};
    if ( bytes::length( $fields->{$field} ) != $width ) {
        confess("Width of '$fields->{$field}' not $width");
    }
    $outstream->print( $fields->{$field} );
}

sub add_segment {
    my ( $self, %args ) = @_;
    my $seg_reader = $args{reader};
    my $doc_map    = $args{doc_map};
    my $doc_max    = $seg_reader->doc_max;

    # Bail if the supplied segment is empty. */
    return unless $doc_max;

    my $outstream = $outstream{$$self} || _lazy_init($self);
    my $doc_reader = $seg_reader->obtain("KinoSearch::Index::DocReader");
    confess("Not a ByteBufDocReader")
        unless ( blessed($doc_reader)
        and $doc_reader->isa("KSx::Index::ByteBufDocReader") );

    for ( my $i = 1; $i <= $doc_max; $i++ ) {
        next unless $doc_map->get($i);
        my $buf;
        $doc_reader->read_record( $i, \$buf );
        $outstream->print($buf);
    }
}

sub finish {
    my $self      = shift;
    my $outstream = $outstream{$$self};
    if ($outstream) {
        $outstream->close;
        my $segment = $self->get_segment;
        $segment->store_metadata(
            key      => 'bytebufdocs',
            metadata => $self->metadata
        );
    }
}

sub format {1}

sub DESTROY {
    my $self = shift;
    delete $field{$$self};
    delete $width{$$self};
    delete $outstream{$$self};
    $self->SUPER::DESTROY;
}

1;

__END__

__POD__

=head1 NAME

KSx::Index::ByteBufDocWriter - Write a Doc as a fixed-width byte array.

=head1 SYNOPSIS

Create an Architecture subclass which overrides register_doc_writer() and
register_doc_reader():

    package MyArchitecture;
    use base qw( KinoSearch::Plan::Architecture );
    use KSx::Index::ByteBufDocReader;
    use KSx::Index::ByteBufDocWriter;

    sub register_doc_writer {
        my ( $self, $seg_writer ) = @_; 
        my $doc_writer = KSx::Index::ByteBufDocWriter->new(
            width      => 16,
            field      => 'id',
            snapshot   => $seg_writer->get_snapshot,
            segment    => $seg_writer->get_segment,
            polyreader => $seg_writer->get_polyreader,
        );  
        $seg_writer->register(
            api       => "KinoSearch::Index::DocReader",
            component => $doc_writer,
        );  
        $seg_writer->add_writer($doc_writer);
    }

    sub register_doc_reader {
        my ( $self, $seg_reader ) = @_; 
        my $doc_reader = KSx::Index::ByteBufDocReader->new(
            width    => 16,
            schema   => $seg_reader->get_schema,
            folder   => $seg_reader->get_folder,
            segments => $seg_reader->get_segments,
            seg_tick => $seg_reader->get_seg_tick,
            snapshot => $seg_reader->get_snapshot,
        );  
        $seg_reader->register(
            api       => 'KinoSearch::Index::DocReader',
            component => $doc_reader,
        );  
    }

    package MySchema;
    use base qw( KinoSearch::Plan::Schema );

    sub architecture { MyArchitecture->new }

Proceed as normal in your indexer app, making sure that every supplied
document supplies a valid value for the field in question:

    $indexer->add_doc({
        title   => $title,
        content => $content,
        id      => $id,      # <---- Must meet spec.
    });

Then, in your search app:

    my $searcher = KinoSearch::Search::IndexSearcher->new( 
        index => '/path/to/index',
    );
    my $hits = $searcher->hits( query => $query );
    while ( my $id = $hits->next ) {
        # $id is a plain old 16-byte Perl scalar instead of a Hit object
        my $real_doc = $external_document_source->fetch($id);
        ...
    }

=head1 DESCRIPTION

This is a proof-of-concept class to demonstrate alternate implementations for
fetching documents.  It is unsupported.

=head1 COPYRIGHT

Copyright 2009-2010 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
