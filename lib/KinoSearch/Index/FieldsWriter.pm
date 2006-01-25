package KinoSearch::Index::FieldsWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use Compress::Zlib qw( compress );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    invindex => undef,
    seg_name => undef,
    # members
    fdata_stream  => undef,
    findex_stream => undef,
);

sub init_instance {
    my $self = shift;

    # open an index stream and a data stream.
    $self->{findex_stream}
        = $self->{invindex}->open_outstream("$self->{seg_name}.fdx");
    $self->{fdata_stream}
        = $self->{invindex}->open_outstream("$self->{seg_name}.fdt");
}

sub add_doc {
    my ( $self, $doc ) = @_;

    # record the data stream's current file pointer in the index.
    $self->{findex_stream}->lu_write( 'Q', $self->{fdata_stream}->tell );

    # only store fields marked as "stored"
    my @stored = sort { $a->get_field_num <=> $b->get_field_num }
        grep $_->get_stored, $doc->get_fields;

    # add the number of stored fields in the Doc
    my @to_write = ( scalar @stored );

    # add flag bits and value for each stored field
    for (@stored) {
        push @to_write, ( $_->get_field_num, $_->get_fdt_bits );
        push @to_write, $_->get_compressed
            ? compress( $_->get_value )
            : $_->get_value;
    }

    # write out data
    my $lu_template = 'V' . ( 'VaT' x scalar @stored );
    $self->{fdata_stream}->lu_write( $lu_template, @to_write );
}

sub finish {
    my $self = shift;
    $self->{fdata_stream}->close;
    $self->{findex_stream}->close;
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::FieldsWriter - write stored fields to an invindex

=head1 DESCRIPTION

FieldsWriter writes fields which are marked as stored to the field data and
field index files.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut

