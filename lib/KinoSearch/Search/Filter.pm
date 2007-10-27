use strict;
use warnings;

package KinoSearch::Search::Filter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # members
    cached_bits => undef,
);

=begin comment

    my $bit_vector = $filter->bits($reader);

Returns a BitVector where set bits correspond to allowed doc nums.

TODO: Maybe rename this method and have it return an IntSet (a superclass of
BitVector which would allow for compact representations).

=end comment
=cut

sub bits { shift->abstract_death }

# Create a wrapping HitCollector which only allows the inner collector to
# "see" documents which pass the filter.
sub make_collector {
    my ( $self, $inner_coll, $reader ) = @_;

    my $filter_bits = $self->bits($reader);

    return $inner_coll unless defined $filter_bits;
    return KinoSearch::Search::HitCollector->new_filt_coll(
        filter_bits => $filter_bits,
        collector   => $inner_coll,
    );
}

# Store a cached BitVector associated with a particular reader.  Store a weak
# reference to the reader as an indicator of cache validity.
sub store_cached_bits {
    my ( $self, $reader, $bits ) = @_;
    my $pair = { reader => $reader, bits => $bits };
    weaken( $pair->{reader} );
    $self->{cached_bits}{ $reader->hash_code } = $pair;
}

# Retrieve a cached BitVector associated with a particular reader.  As a side
# effect, clear away any BitVectors which are no longer valid because their
# readers have gone away.
sub fetch_cached_bits {
    my ( $self, $reader ) = @_;
    my $cached_bits = $self->{cached_bits};

    # sweep
    while ( my ( $hash_code, $pair ) = each %$cached_bits ) {
        # if weak ref has decomposed into undef, reader is gone... so delete
        next if defined $pair->{reader};
        delete $cached_bits->{$hash_code};
    }

    # fetch
    my $pair = $cached_bits->{ $reader->hash_code };
    return $pair->{bits} if defined $pair;
    return;
}

1;

__END__

=head1 NAME

KinoSearch::Search::Filter - Base Filter class

=head1 DESCRIPTION

Filter is an abstract base class, with no public methods.  

Subclasses of Filter include L<QueryFilter|KinoSearch::Search::QueryFilter>,
L<RangeFilter|KinoSearch::Search::RangeFilter>, and
L<PolyFilter|KinoSearch::Search::PolyFilter>.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
