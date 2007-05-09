use strict;
use warnings;

package KinoSearch::Search::PolyFilter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Filter );

our %instance_vars = (
    # inherited
    cached_bits => {},

    # members
    filters => [],
);

sub bits {
    my ( $self, $reader ) = @_;

    return undef unless @{ $self->{filters} };

    my $cached_bits = $self->fetch_cached_bits($reader);

    # fill the cache
    if ( !defined $cached_bits ) {
        for my $filter ( @{ $self->{filters} } ) {
            my $bits  = $filter->{filter}->bits($reader);
            my $logic = uc( $filter->{logic} ) || 'AND';

            if ( !defined $cached_bits ) {
                $cached_bits = $bits->clone;
                $self->store_cached_bits( $reader, $cached_bits );
                if ( $logic eq 'NOT' ) {
                    $cached_bits->flip_range( 0, $reader->max_doc );
                }
            }
            elsif ( $logic eq 'XOR' ) {
                $cached_bits->XOR($bits);
            }
            elsif ( $logic eq 'OR' ) {
                $cached_bits->OR($bits);
            }
            elsif ( $logic eq 'NOT' ) {
                $cached_bits->AND_NOT($bits);
            }
            else {    # default: ($logic eq 'AND') {
                $cached_bits->AND($bits);
            }
        }

    }

    return $cached_bits;

}

my %add_args = (
    filter => undef,
    logic  => undef,
);

sub add {
    my $self = shift;
    confess kerror() unless verify_args( \%add_args, @_ );
    my %args = ( %add_args, @_ );
    confess("Missing required parameter filter") unless defined $args{filter};

    push @{ $self->{filters} }, \%args;
    $self->{cached_bits} = {};    # invalidate cache

    return 1;
}

1;

__END__

=head1 NAME

KinoSearch::Search::PolyFilter - Combine filters for a search.

=head1 SYNOPSIS

    my $polyfilter = KinoSearch::Search::PolyFilter->new;
    $polyfilter->add( filter => $query_filter );
    $polyfilter->add( filter => $range_filter, logic => 'AND' );
    my $hits = $searcher->search( query => $query, filter => $polyfilter );

=head1 DESCRIPTION 

A PolyFilter is a chain of L<Filter|KinoSearch::Search::Filter> objects which
may be combined using boolean logic, making it possible to do things like
filter by multiple ranges, or to apply both a RangeFilter and a QueryFilter
to the same query.

During search, the sub-filters are applied in the order that they were added.

=head1 METHODS

=head2 new

    my $filter = KinoSearch::Search::PolyFilter->new;

Constructor.  Takes no parameters.

=head2 add

    $polyfilter->add( 
        filter => $query_filter,  # required
        logic => 'OR',            # default: 'AND'
    );

Adds a filter to the query.

=over

=item *

B<filter> - the L<Filter|KinoSearch::Search::Filter> object to add to the
PolyFilter, which might be a L<QueryFilter|KinoSearch::Search::QueryFilter>, a
L<RangeFilter|KinoSearch::Search::RangeFilter>, or another PolyFilter.

=item *

B<logic> - C<AND>, C<NOT>, C<OR>, or C<XOR>.  Optional; default is C<AND>.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
