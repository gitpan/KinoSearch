use strict;
use warnings;

package KinoSearch::Index::SegReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::IndexReader );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # params/members
        seg_info => undef,

        # members
        schema           => undef,
        comp_file_reader => undef,
        tl_reader        => undef,
        doc_reader       => undef,
        tv_reader        => undef,
        deldocs          => undef,
        metadata         => undef,
        deldocs_dirty    => 0,
    );

    __PACKAGE__->ready_get(
        qw(
            schema
            comp_file_reader
            seg_info
            doc_reader
            tl_reader
            tv_reader
            deldocs
            )
    );
}

use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::IndexFileNames
    qw( filename_from_gen gen_from_file_name );
use KinoSearch::Index::TermListReader;
use KinoSearch::Index::SegTermList;
use KinoSearch::Index::TermVectorsReader;
use KinoSearch::Index::DocReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegTermDocs;
use KinoSearch::Index::DelDocs;
use KinoSearch::Util::VArray;

# use KinoSearch::Util::Class's new()
# Note: can't inherit IndexReader's new() without recursion problems
*new = *KinoSearch::Util::Class::new;

sub init_instance {
    my $self = shift;
    my ( $invindex, $seg_info ) = @{$self}{qw( invindex seg_info )};

    # extract schema
    my $schema = $self->{schema} = $invindex->get_schema;

    # initialize DelDocs
    $self->{deldocs} = KinoSearch::Index::DelDocs->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );

    # initialize a CompoundFileReader
    my $comp_file_reader = $self->{comp_file_reader}
        = KinoSearch::Index::CompoundFileReader->new(
        invindex => $invindex,
        seg_info => $seg_info,
        );

    # initialize DocReader
    $self->{doc_reader} = KinoSearch::Index::DocReader->new(
        schema   => $schema,
        folder   => $comp_file_reader,
        seg_info => $seg_info,
    );

    # load TermLists
    $self->{tl_reader} = KinoSearch::Index::TermListReader->new(
        schema   => $schema,
        folder   => $comp_file_reader,
        seg_info => $seg_info,
    );

    # initialize TermVectorsReader
    $self->{tv_reader} = KinoSearch::Index::TermVectorsReader->new(
        schema   => $schema,
        folder   => $comp_file_reader,
        seg_info => $seg_info,
    );
}

sub get_seg_name { shift->{seg_info}->get_seg_name }

sub max_doc { shift->{seg_info}->get_doc_count }

sub num_docs {
    my $self = shift;
    return $self->max_doc - $self->{deldocs}->get_num_deletions;
}

sub delete_docs_by_term {
    my ( $self, $term ) = @_;
    my $term_docs = $self->term_docs($term);
    $self->{deldocs}->delete_by_term_docs($term_docs);
    $self->{deldocs_dirty} = 1;
}

sub write_deletions {
    my $self = shift;
    return unless $self->{deldocs_dirty};
    return unless $self->{deldocs}->get_num_deletions;
    $self->{deldocs}->write_deldocs;
}

sub field_terms       { $_[0]->{tl_reader}->field_terms( $_[1] ) }
sub start_field_terms { $_[0]->{tl_reader}->start_field_terms( $_[1] ) }
sub fetch_term_info   { $_[0]->{tl_reader}->fetch_term_info( $_[1] ) }
sub get_skip_interval { $_[0]->{tl_reader}->get_skip_interval }

sub doc_freq {
    my ( $self, $term ) = @_;
    my $tinfo = $self->fetch_term_info($term);
    return defined $tinfo ? $tinfo->get_doc_freq : 0;
}

sub term_docs {
    my ( $self, $term ) = @_;
    my $term_docs
        = KinoSearch::Index::SegTermDocs->new( seg_reader => $self, );
    $term_docs->seek($term);
    return $term_docs;
}

sub fetch_doc {
    $_[0]->{doc_reader}->fetch_doc( $_[1] );
}

sub fetch_doc_vec {
    $_[0]->{tv_reader}->doc_vec( $_[1] );
}

sub segreaders_to_merge {
    my ( $self, $all ) = @_;
    return $self if $all;
    return;
}

sub close {
    my $self = shift;
    $self->{deldocs}->close;
    $self->{doc_reader}->close;
    $self->{tv_reader}->close;
    $self->{tl_reader}->close;
    $self->{comp_file_reader}->close;
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegReader - Read from a single-segment InvIndex.

=head1 DESCRIPTION

Single-segment implementation of IndexReader.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

