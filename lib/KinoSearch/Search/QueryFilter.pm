use strict;
use warnings;

package KinoSearch::Search::QueryFilter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        query => undef,
        # members
        cached_bits => undef,
    );
}

use KinoSearch::Search::HitCollector;
use KinoSearch::Util::BitVector;

sub init_instance {
    my $self = shift;
    confess("required parameter query is not a KinoSearch::Search::Query")
        unless a_isa_b( $self->{query}, 'KinoSearch::Search::Query' );
}

sub bits {
    my ( $self, $searcher ) = @_;

    # fill the cache
    if ( !defined $self->{cached_bits} ) {
        $self->{cached_bits} = KinoSearch::Util::BitVector->new(
            capacity => $searcher->max_doc );

        my $collector = KinoSearch::Search::HitCollector->new_bit_coll(
            bit_vector => $self->{cached_bits} );

        # perform the search
        $searcher->search_hit_collector(
            weight        => $self->{query}->to_weight($searcher),
            hit_collector => $collector,
        );
    }

    return $self->{cached_bits};
}

sub make_collector {
    my ( $self, $inner_coll, $searcher ) = @_;
    return KinoSearch::Search::HitCollector->new_filt_coll(
        filter_bits   => $self->bits($searcher),
        hit_collector => $inner_coll,
    );
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

See L<KinoSearch> version 0.20_01.

=cut
