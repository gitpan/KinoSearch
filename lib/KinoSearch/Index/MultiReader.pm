use strict;
use warnings;

package KinoSearch::Index::MultiReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::IndexReader );

our %instance_vars = (
    # inherited params / members
    invindex     => undef,
    seg_infos    => undef,
    lock_factory => undef,

    # params / members
    sub_readers => [],

    # inherited members
    sort_caches => {},
    lex_caches  => {},
    read_lock   => undef,
    commit_lock => undef,

    # members
    max_doc => 0,
    starts  => [],
);

use KinoSearch::Index::SegReader;
use KinoSearch::Index::MultiPostingList;
use KinoSearch::Index::MultiPostingList;
use KinoSearch::Index::MultiLexicon;
use KinoSearch::Util::VArray;
use KinoSearch::Util::Int;

# use KinoSearch::Util::Class's new()
# Note: can't inherit IndexReader's new() without recursion problems
*new = *KinoSearch::Util::Class::new;

sub init_instance {
    my $self = shift;

    $self->_init_sub_readers;
}

sub _init_sub_readers {
    my $self = shift;
    my @starts;
    my $max_doc = 0;
    for my $sub_reader ( @{ $self->{sub_readers} } ) {
        push @starts, $max_doc;
        $max_doc += $sub_reader->max_doc;
    }
    $self->{starts}  = \@starts;
    $self->{max_doc} = $max_doc;
}

sub max_doc { shift->{max_doc} }

sub num_docs {
    my $self = shift;

    my $num_docs = 0;
    $num_docs += $_->num_docs for @{ $self->{sub_readers} };

    return $num_docs;
}

sub look_up_term {
    my ( $self, $term ) = @_;
    return unless defined $term;
    my $lexicon = $self->look_up_field( $term->get_field );
    $lexicon->seek($term);
    return $lexicon;
}

sub look_up_field {
    my ( $self, $field ) = @_;
    return unless defined $field;
    my $fspec = $self->{invindex}->get_schema->fetch_fspec($field);
    return unless ( defined $fspec and $fspec->indexed );
    my $lexicon = KinoSearch::Index::MultiLexicon->new(
        sub_readers => $self->{sub_readers},
        field       => $field,
        lex_cache   => $self->{lex_caches}{$field},
    );
    return $lexicon;
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
    my $plist = KinoSearch::Index::MultiPostingList->new(
        sub_readers => $self->{sub_readers},
        starts      => $self->get_seg_starts,
        field       => $field,
    );
    $plist->seek($term) if defined $term;

    return $plist;
}

sub doc_freq {
    my ( $self, $term ) = @_;
    my $doc_freq = 0;
    $doc_freq += $_->doc_freq($term) for @{ $self->{sub_readers} };
    return $doc_freq;
}

sub fetch_doc {
    my ( $self, $doc_num ) = @_;
    my $reader_index = $self->_reader_index($doc_num);
    $doc_num -= $self->{starts}[$reader_index];
    return $self->{sub_readers}[$reader_index]->fetch_doc($doc_num);
}

sub fetch_doc_vec {
    my ( $self, $doc_num ) = @_;
    my $reader_index = $self->_reader_index($doc_num);
    $doc_num -= $self->{starts}[$reader_index];
    return $self->{sub_readers}[$reader_index]->fetch_doc_vec($doc_num);
}

sub delete_docs_by_term {
    my ( $self, $term ) = @_;
    $_->delete_docs_by_term($term) for @{ $self->{sub_readers} };
}

sub write_deletions {
    my $self = shift;
    $_->write_deletions for @{ $self->{sub_readers} };
}

# Determine which sub-reader a document resides in
sub _reader_index {
    my ( $self, $doc_num ) = @_;
    my $starts = $self->{starts};
    my ( $lo, $mid, $hi ) = ( 0, undef, $#$starts );
    while ( $hi >= $lo ) {
        $mid = ( $lo + $hi ) >> 1;
        my $mid_start = $starts->[$mid];
        if ( $doc_num < $mid_start ) {
            $hi = $mid - 1;
        }
        elsif ( $doc_num > $mid_start ) {
            $lo = $mid + 1;
        }
        else {
            while ( $mid < $#$starts and $starts->[ $mid + 1 ] == $mid_start )
            {
                $mid++;
            }
            return $mid;
        }

    }
    return $hi;
}

sub segreaders_to_merge {
    my ( $self, $all ) = @_;
    return unless @{ $self->{sub_readers} };
    return @{ $self->{sub_readers} } if $all;

    # sort by ascending size in docs
    my @sorted_sub_readers
        = sort { $a->num_docs <=> $b->num_docs } @{ $self->{sub_readers} };

    # find sparsely populated segments
    my $total_docs = 0;
    my $threshold  = -1;
    for my $i ( 0 .. $#sorted_sub_readers ) {
        $total_docs += $sorted_sub_readers[$i]->num_docs;
        if ( $total_docs < fibonacci( $i + 5 ) ) {
            $threshold = $i;
        }
    }

    # if any of the segments are sparse, return their readers
    if ( $threshold > -1 ) {
        return @sorted_sub_readers[ 0 .. $threshold ];
    }
    else {
        return;
    }
}

# Generate fibonacci series
my %fibo_cache;

sub fibonacci {
    my $n = shift;
    return $fibo_cache{$n} if exists $fibo_cache{$n};
    my $result = $n < 2 ? $n : fibonacci( $n - 1 ) + fibonacci( $n - 2 );
    $fibo_cache{$n} = $result;
    return $result;
}

sub get_seg_starts {
    my $self       = shift;
    my $num_starts = scalar @{ $self->{starts} };
    my $starts     = KinoSearch::Util::VArray->new( capacity => $num_starts );
    for my $start ( @{ $self->{starts} } ) {
        $starts->push( KinoSearch::Util::Int->new($start) );
    }
    return $starts;
}

sub close {
    my $self = shift;
    $_->close for @{ $self->{sub_readers} };
    $self->SUPER::close;
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::MultiReader - Read from a multi-segment InvIndex.

=head1 DESCRIPTION 

Multi-segment implementation of IndexReader.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
