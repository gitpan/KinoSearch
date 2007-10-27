use strict;
use warnings;

package KinoSearch::Search::QueryFilter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Filter );

our %instance_vars = (
    # inherited
    cached_bits => undef,

    # constructor params / members
    query => undef,
);

use KinoSearch::Search::HitCollector;
use KinoSearch::Util::BitVector;

sub init_instance {
    my $self = shift;
    confess("required parameter query is not a KinoSearch::Search::Query")
        unless a_isa_b( $self->{query}, 'KinoSearch::Search::Query' );
    $self->{cached_bits} = {};
}

sub bits {
    my ( $self, $reader ) = @_;

    my $cached_bits = $self->fetch_cached_bits($reader);

    # fill the cache
    if ( !defined $cached_bits ) {
        $cached_bits = KinoSearch::Util::BitVector->new(
            capacity => $reader->max_doc );
        $self->store_cached_bits( $reader, $cached_bits );

        my $collector = KinoSearch::Search::HitCollector->new_bit_coll(
            bit_vector => $cached_bits );

        my $searcher = KinoSearch::Searcher->new( reader => $reader );

        # perform the search
        $searcher->collect(
            query     => $self->{query},
            collector => $collector,
        );
    }

    return $cached_bits;
}

1;

__END__

=head1 NAME

KinoSearch::Search::QueryFilter - Build a filter based on results of a query.

=head1 SYNOPSIS

    my $books_only_query  = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'category', 'books' ),
    );
    my $filter = KinoSearch::Search::QueryFilter->new(
        query => $books_only_query;
    );
    my $hits = $searcher->search(
        query  => $query_string,
        filter => $filter,
    );

=head1 DESCRIPTION 

A QueryFilter spawns a result set that can be used to filter the results of
another query.  The effect is very similar to adding a required clause to a
L<BooleanQuery|KinoSearch::Search::BooleanQuery> -- however, a QueryFilter
caches its results, so it is more efficient if you use it more than once.

=head1 METHODS

=head2 new

    my $filter = KinoSearch::Search::QueryFilter->new(
        query => $query;
    );

Constructor.  Takes one hash-style parameter, C<query>, which must be an object
belonging to a subclass of L<KinoSearch::Search::Query>.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
