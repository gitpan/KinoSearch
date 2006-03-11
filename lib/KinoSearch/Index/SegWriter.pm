package KinoSearch::Index::SegWriter;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Index::FieldsWriter;
use KinoSearch::Index::PostingsWriter;
use KinoSearch::Index::CompoundFileWriter;
use KinoSearch::Index::IndexFileNames qw( @COMPOUND_EXTENSIONS );
use KinoSearch::Search::Similarity;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    invindex   => undef,
    seg_name   => undef,
    finfos     => undef,
    similarity => undef,
    # members
    norm_outstreams => [],
    fields_writer   => undef,
    postings_writer => undef,
    doc_count       => 0,
);

sub init_instance {
    my $self = shift;
    my ( $invindex, $norm_outstreams, $seg_name, $finfos )
        = @{$self}{ 'invindex', 'norm_outstreams', 'seg_name', 'finfos' };

    # init norms
    my @indexed_field_nums = map { $_->get_field_num }
        grep { $_->get_indexed } $finfos->get_infos;
    for my $field_num (@indexed_field_nums) {
        $norm_outstreams->[$field_num]
            = $invindex->open_outstream("$seg_name.f$field_num");
    }

    # init FieldsWriter
    $self->{fields_writer} = KinoSearch::Index::FieldsWriter->new(
        invindex => $invindex,
        seg_name => $seg_name,
    );

    # init PostingsWriter
    $self->{postings_writer} = KinoSearch::Index::PostingsWriter->new(
        invindex => $invindex,
        seg_name => $seg_name,
    );
}

sub get_seg_name  { $_[0]->{seg_name} }
sub get_doc_count { $_[0]->{doc_count} }

# Add a document to the segment.
sub add_doc {
    my ( $self, $doc ) = @_;
    my $norm_outstreams = $self->{norm_outstreams};
    my $postings_cache  = $self->{postings_cache};
    my $similarity      = $self->{similarity};
    my $doc_boost       = $doc->get_boost;

    for my $indexed_field ( grep { $_->get_indexed } $doc->get_fields ) {
        my $token_batch = KinoSearch::Analysis::TokenBatch->new;

        if ( $indexed_field->get_value_len ) {
            $token_batch->add_token( $indexed_field->get_value, 0,
                $indexed_field->get_value_len );
        }
        if ( $indexed_field->get_analyzed ) {
            $token_batch
                = $indexed_field->get_analyzer()->analyze($token_batch);
        }

        $token_batch->build_posting_list( $self->{doc_count},
            $indexed_field->get_field_num );

        if ( $indexed_field->get_vectorized and $indexed_field->get_stored ) {
            $indexed_field->set_tv_string( $token_batch->get_tv_string );
        }

        # encode a norm into a byte, write it to an outstream
        my $norm_val = $doc_boost * $indexed_field->get_boost
            * $similarity->lengthnorm( $token_batch->get_size );
        my $outstream = $norm_outstreams->[ $indexed_field->get_field_num ];
        $outstream->lu_write( 'a', $similarity->encode_norm($norm_val) );

        # feed PostingsWriter
        $self->{postings_writer}->add_postings( $token_batch->get_postings );
    }

    # store fields
    $self->{fields_writer}->add_doc($doc);

    $self->{doc_count}++;
}

# Finish writing the segment.
sub finish {
    my $self = shift;
    my ( $invindex, $seg_name ) = @{$self}{ 'invindex', 'seg_name' };

    # write Term Dictionary, positions.
    $self->{postings_writer}->write_postings;

    # write FieldInfos
    my $finfos_outstream = $invindex->open_outstream("$seg_name.fnm");
    $self->{finfos}->write_infos($finfos_outstream);
    $finfos_outstream->close;

    # close down all the writers, so we can open the files they've finished.
    $self->{postings_writer}->finish;
    $self->{fields_writer}->finish;
    for ( @{ $self->{norm_outstreams} } ) {
        $_->close if defined;
    }

    # consolidate compound file
    unless ( $self->{_dont_use_comp_file} ) {    # testing hack - always runs
        my $compound_file_writer = KinoSearch::Index::CompoundFileWriter->new(
            invindex => $invindex,
            filename => "$seg_name.tmp",
        );
        my @compound_files = map {"$seg_name.$_"} @COMPOUND_EXTENSIONS;
        push @compound_files, map { "$seg_name.f" . $_->get_field_num }
            grep { $_->get_indexed } $self->{finfos}->get_infos;
        $compound_file_writer->add_file($_) for @compound_files;
        $compound_file_writer->finish;
        $invindex->rename_file( "$seg_name.tmp", "$seg_name.cfs" );
        $invindex->delete_file($_) for @compound_files;
    }

}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegWriter - write one segment of an invindex

=head1 DESCRIPTION

SegWriter is a conduit through which information fed to InvIndexer passes on
its way to low-level writers such as FieldsWriter and TermInfosWriter.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.08.

=end devdocs
=cut
