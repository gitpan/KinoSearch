use strict;
use warnings;

package KinoSearch::Index::SegWriter;
use KinoSearch::Util::ToolSet;
use KinoSearch::Util::StringHelper qw( utf8ify );
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    invindex => undef,
    seg_info => undef,

    # members
    schema          => undef,
    doc_writer      => undef,
    postings_writer => undef,
    tv_writer       => undef,
    pre_sorter      => undef,
    pre_sort_field  => undef,
);

BEGIN { __PACKAGE__->ready_get(qw( seg_info )) }

use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Index::DocWriter;
use KinoSearch::Index::PostingsWriter;
use KinoSearch::Index::TermVectorsWriter;
use KinoSearch::Index::CompoundFileWriter;
use KinoSearch::Index::IndexFileNames
    qw( @COMPOUND_EXTENSIONS @SCRATCH_EXTENSIONS );
use KinoSearch::Util::Obj;

sub init_instance {
    my $self = shift;
    my ( $seg_info, $invindex ) = @{$self}{qw( seg_info invindex )};

    # extract schema
    $self->{schema} = $invindex->get_schema;

    # prepare for pre_sort
    my $pre_sort_spec = $self->{schema}->pre_sort;
    if ( defined $pre_sort_spec ) {
        $self->{pre_sort_field} = $pre_sort_spec->{field};
        $self->{pre_sorter}     = KinoSearch::Index::PreSorter->new(
            field   => $pre_sort_spec->{field},
            reverse => $pre_sort_spec->{reverse},
        );
    }

    # init DocWriter, PostingsWriter, and TV Writer
    $self->{doc_writer} = KinoSearch::Index::DocWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );
    $self->{postings_writer} = KinoSearch::Index::PostingsWriter->new(
        invindex   => $invindex,
        seg_info   => $seg_info,
        pre_sorter => $self->{pre_sorter},
    );
    $self->{tv_writer} = KinoSearch::Index::TermVectorsWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );
}

# Add a document to the segment.
sub add_doc {
    my ( $self, $doc, $doc_boost ) = @_;
    my ( $schema, $seg_info, $tv_writer, $postings_writer )
        = @{$self}{qw( schema seg_info tv_writer postings_writer )};
    my $doc_num    = $seg_info->get_doc_count;
    my $doc_vector = KinoSearch::Index::DocVector->new;

    # process pre-sort data if enabled
    if ( defined $self->{pre_sort_field} ) {
        $self->{pre_sorter}
            ->add_val( $doc_num, $doc->{ $self->{pre_sort_field} } );
    }

    # iterate over fields
    for my $field_name ( keys %$doc ) {
        # verify that field is in schema
        my $field_spec = $schema->fetch_fspec($field_name);
        confess("Unknown field name: '$field_name'")
            unless defined $field_spec;

        # add field to segment if it's new
        if ( !defined $seg_info->field_num($field_name) ) {
            $seg_info->add_field($field_name);
        }

        # upgrade fields that aren't binary to utf8
        if ( !$field_spec->binary ) {
            utf8ify( $doc->{$field_name} );
        }

        next unless $field_spec->indexed;

        # get a TokenBatch, going through analyzer if appropriate
        my $token_batch;
        if ( $field_spec->analyzed ) {
            my $analyzer = $schema->fetch_analyzer($field_name);
            $token_batch = $analyzer->analyze_field( $doc, $field_name );
        }
        else {
            $token_batch = KinoSearch::Analysis::TokenBatch->new(
                text => $doc->{$field_name} );
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
            field_name  => $field_name,
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
    my $seg_info     = $self->{seg_info};
    my $old_seg_info = $seg_reader->get_seg_info;

    # prepare to bulk add
    my $deldocs = $seg_reader->get_deldocs;
    my $doc_map = $deldocs->generate_doc_map( $seg_info->get_doc_count );

    # bulk add the slab of documents to the various writers
    $self->{pre_sorter}->add_segment( $seg_reader, $doc_map )
        if defined $self->{pre_sorter};
    $self->{postings_writer}->add_segment( $seg_reader, $doc_map );
    $self->{doc_writer}->add_segment( $seg_reader,      $doc_map );
    $self->{tv_writer}->add_segment( $seg_reader,       $doc_map );

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

    # get a pre-sort doc num map (or undef if pre-sort not enabled)
    my $pre_sort_remap;
    if ( defined $self->{pre_sorter} ) {
        $pre_sort_remap = $self->{pre_sorter}->gen_remap;
        my $doc_count  = $seg_info->get_doc_count;
        my $remap_size = $pre_sort_remap->get_size;
        confess("Mismatched PreSort remap size: $remap_size $doc_count")
            if $remap_size != $doc_count;
    }

    # close down all the writers, so we can open the files they've finished.
    $self->{postings_writer}->finish;
    $self->{doc_writer}->finish($pre_sort_remap);
    $self->{tv_writer}->finish($pre_sort_remap);

    # write compound file
    my $compound_file_writer = KinoSearch::Index::CompoundFileWriter->new(
        invindex => $self->{invindex},
        seg_info => $seg_info,
    );
    my @compound_files = map {"$seg_name.$_"} @COMPOUND_EXTENSIONS;
    for ( 0 .. $schema->num_fields ) {
        push @compound_files, "$seg_name.p$_";
        push @compound_files, "$seg_name.lex$_";
        push @compound_files, "$seg_name.lexx$_";
    }
    @compound_files = grep { $folder->file_exists($_) } @compound_files;
    $compound_file_writer->add_file($_) for @compound_files;
    $compound_file_writer->finish;

    # delete files that are no longer needed;
    $folder->delete_file($_) for @compound_files;
    for my $scratch_extension (@SCRATCH_EXTENSIONS) {
        my $scratch = "$seg_name.$scratch_extension";
        $folder->delete_file($scratch)
            if $folder->file_exists($scratch);
    }
}

1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegWriter - Write one segment of an InvIndex.

=head1 DESCRIPTION

SegWriter is a conduit through which information fed to InvIndexer passes on
its way to low-level writers such as DocWriter and LexWriter.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
