use strict;
use warnings;

package KinoSearch::Index::SegReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::IndexReader );

our %instance_vars = (
    # inherited params / members
    invindex     => undef,
    seg_infos    => undef,
    lock_factory => undef,

    # params / members
    seg_info => undef,

    # inherited members
    sort_caches => undef,
    lex_caches  => undef,
    read_lock   => undef,
    commit_lock => undef,

    # members
    schema           => undef,
    comp_file_reader => undef,
    lex_reader       => undef,
    doc_reader       => undef,
    tv_reader        => undef,
    deldocs          => undef,
    metadata         => undef,
    deldocs_dirty    => 0,
    delcount         => undef,
);

BEGIN {
    __PACKAGE__->ready_get(
        qw(
            comp_file_reader
            seg_info
            doc_reader
            lex_reader
            tv_reader
            deldocs
            )
    );
}

use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::IndexFileNames
    qw( filename_from_gen gen_from_filename );
use KinoSearch::Index::LexReader;
use KinoSearch::Index::SegLexicon;
use KinoSearch::Index::TermVectorsReader;
use KinoSearch::Index::DocReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegPostingList;
use KinoSearch::Index::DelDocs;
use KinoSearch::Util::VArray;
use KinoSearch::Util::Int;

# use KinoSearch::Util::Class's new()
# Note: can't inherit IndexReader's new() without recursion problems
*new = *KinoSearch::Util::Class::new;

sub init_instance {
    my $self = shift;
    my ( $invindex, $seg_info ) = @{$self}{qw( invindex seg_info )};
    $self->{sort_caches} = {};
    $self->{lex_caches}  = {};

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

    # load Lexicons
    $self->{lex_reader} = KinoSearch::Index::LexReader->new(
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
    if ( !defined $self->{delcount} ) {
        $self->{delcount} = $self->{deldocs}->get_num_deletions;
    }
    return $self->max_doc - $self->{delcount};
}

sub delete_docs_by_term {
    my ( $self, $term ) = @_;
    my $plist = $self->posting_list( term => $term );
    $self->{deldocs}->delete_posting_list($plist);
    $self->{deldocs_dirty} = 1;
    undef $self->{delcount};
}

sub write_deletions {
    my $self = shift;
    return unless $self->{deldocs_dirty};
    return unless $self->{deldocs}->get_num_deletions;
    $self->{deldocs}->write_deldocs;
}

sub has_deletions {
    my $self = shift;
    return 1 if ( $self->{deldocs_dirty} || $self->{delcount} );
    return;
}

sub look_up_term      { $_[0]->{lex_reader}->look_up_term( $_[1] ) }
sub look_up_field     { $_[0]->{lex_reader}->look_up_field( $_[1] ) }
sub fetch_term_info   { $_[0]->{lex_reader}->fetch_term_info( $_[1] ) }
sub get_skip_interval { $_[0]->{lex_reader}->get_skip_interval }

sub doc_freq {
    my ( $self, $term ) = @_;
    my $tinfo = $self->fetch_term_info($term);
    return defined $tinfo ? $tinfo->get_doc_freq : 0;
}

sub posting_list {
    my $self = shift;
    confess kerror()
        unless verify_args( { term => undef, field => undef, }, @_ );
    my %args = @_;

    # only return an object if we've got an indexed field
    my ( $field, $term ) = @args{qw( field term )};
    return unless ( defined $field or defined $term );
    $field = $term->get_field unless defined $field;
    my $fspec = $self->{invindex}->get_schema->fetch_fspec($field);
    return unless defined $fspec;
    return unless $fspec->indexed;

    # create a PostingList and seek it if a Term was supplied
    my $plist = KinoSearch::Index::SegPostingList->new(
        seg_reader => $self,
        field      => $field,
    );
    $plist->seek($term) if defined $term;

    return $plist;
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

sub get_seg_starts {
    my $self = shift;
    my $starts = KinoSearch::Util::VArray->new( capacity => 1 );
    $starts->push( KinoSearch::Util::Int->new(0) );
    return $starts;
}

sub close {
    my $self = shift;
    $self->{deldocs}->close;
    $self->{doc_reader}->close;
    $self->{tv_reader}->close;
    $self->{lex_reader}->close;
    $self->{comp_file_reader}->close;
    $self->SUPER::close;
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
