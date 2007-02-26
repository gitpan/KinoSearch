use strict;
use warnings;

package KinoSearch::Index::SegWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        invindex => undef,
        seg_info => undef,
        # members
        schema          => undef,
        doc_writer      => undef,
        postings_writer => undef,
        tv_writer       => undef,
    );
    __PACKAGE__->ready_get(qw( seg_info ));
}

use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Index::DocWriter;
use KinoSearch::Index::PostingsWriter;
use KinoSearch::Index::TermVectorsWriter;
use KinoSearch::Index::CompoundFileWriter;
use KinoSearch::Index::IndexFileNames
    qw( @COMPOUND_EXTENSIONS SORTFILE_EXTENSION );

sub init_instance {
    my $self = shift;
    my ( $seg_info, $invindex ) = @{$self}{qw( seg_info invindex )};

    # extract schema
    $self->{schema} = $invindex->get_schema;

    # init DocWriter, PostingsWriter, and TV Writer
    $self->{doc_writer} = KinoSearch::Index::DocWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );
    $self->{postings_writer} = KinoSearch::Index::PostingsWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );
    $self->{tv_writer} = KinoSearch::Index::TermVectorsWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );
}

# Add a document to the segment.
sub add_doc {
    my ( $self, $doc, $doc_boost ) = @_;
    my ( $schema, $seg_info, $tv_writer )
        = @{$self}{qw( schema seg_info tv_writer )};
    my $doc_num    = $seg_info->get_doc_count;
    my $doc_vector = KinoSearch::Index::DocVector->new;

    # analyze and invert field values
    for my $field_name ( keys %$doc ) {
        my $field_spec = $schema->fetch_fspec($field_name);
        confess("Unknown field name: '$field_name'")
            unless defined $field_spec;
        next unless $field_spec->indexed;

        my $token_batch = KinoSearch::Analysis::TokenBatch->new(
            text => $doc->{$field_name} );

        # analyze the field
        if ( $field_spec->analyzed ) {
            my $analyzer = $schema->fetch_analyzer($field_name);
            $token_batch = $analyzer->analyze($token_batch);
        }

        # invert the field's tokens;
        $token_batch->invert;

        # generate term vector strings
        if ( $field_spec->vectorized ) {
            $doc_vector->add_field_string( $field_name,
                $tv_writer->tv_string($token_batch) );
        }

        # feed PostingsWriter
        my $sim = $schema->fetch_sim($field_name);
        $self->{postings_writer}->add_batch(
            token_batch => $token_batch,
            field_spec  => $field_spec,
            doc_num     => $doc_num,
            doc_boost   => $doc_boost,
            length_norm => $sim->length_norm( $token_batch->get_size ),
        );
    }

    # store fields and term vectors
    $self->{doc_writer}->add_doc($doc);
    $tv_writer->add_doc_vec($doc_vector);

    # add to the tally
    $seg_info->increment_doc_count;
}

sub add_segment {
    my ( $self, $seg_reader ) = @_;
    my $seg_info = $self->{seg_info};

    # prepare to bulk add
    my $deldocs = $seg_reader->get_deldocs;
    my $doc_map = $deldocs->generate_doc_map( $seg_info->get_doc_count );
    my $fnum_map
        = $seg_info->generate_field_num_map( $seg_reader->get_seg_info );

    # bulk add the slab of documents to the various writers
    $self->{doc_writer}->add_segment( $seg_reader,      $doc_map, $fnum_map );
    $self->{postings_writer}->add_segment( $seg_reader, $doc_map, $fnum_map );
    $self->{tv_writer}->add_segment( $seg_reader,       $doc_map, $fnum_map );

    $seg_info->set_doc_count(
        $seg_info->get_doc_count + $seg_reader->num_docs );
}

# Finish writing the segment.
sub finish {
    my $self     = shift;
    my $seg_info = $self->{seg_info};
    my $schema   = $self->{schema};
    my $seg_name = $seg_info->get_seg_name;
    my $folder   = $self->{invindex}->get_folder;

    # write Term Dictionary, positions.
    $self->{postings_writer}->write_postings;

    # close down all the writers, so we can open the files they've finished.
    $self->{postings_writer}->finish;
    $self->{doc_writer}->finish;
    $self->{tv_writer}->finish;

    # write compound file
    my $compound_file_writer = KinoSearch::Index::CompoundFileWriter->new(
        invindex => $self->{invindex},
        seg_info => $seg_info,
    );
    my @compound_files = map {"$seg_name.$_"} @COMPOUND_EXTENSIONS;
    for ( 0 .. $schema->num_fields ) {
        push @compound_files, "$seg_name.p$_";
        push @compound_files, "$seg_name.tl$_";
        push @compound_files, "$seg_name.tlx$_";
    }
    @compound_files = grep { $folder->file_exists($_) } @compound_files;
    $compound_file_writer->add_file($_) for @compound_files;
    $compound_file_writer->finish;

    # delete files that are no longer needed;
    $folder->delete_file($_) for @compound_files;
    my $sort_file_name = $seg_name . SORTFILE_EXTENSION;
    $folder->delete_file($sort_file_name)
        if $folder->file_exists($sort_file_name);
}

1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegWriter - Write one segment of an InvIndex.

=head1 DESCRIPTION

SegWriter is a conduit through which information fed to InvIndexer passes on
its way to low-level writers such as DocWriter and TermListWriter.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
