use strict;
use warnings;

package KinoSearch::Search::RangeFilter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Filter );

use KinoSearch::Search::HitCollector;
use KinoSearch::Search::MatchFieldQuery;

our %instance_vars = (
    # inherited (but useless)
    cached_bits => undef,

    # params / members
    field         => undef,
    lower_term    => undef,
    upper_term    => undef,
    include_lower => 1,
    include_upper => 1,
);

sub init_instance {
    my $self = shift;

    confess("Missing required parameter 'field'")
        unless defined $self->{field};
    confess("Must supply either lower_term or upper_term (or both)")
        unless ( defined $self->{lower_term}
        or defined $self->{upper_term} );
}

sub bits {
    my ( $self, $reader ) = @_;

    # collect docs that have a value for this field which passes the filter
    my $bits
        = KinoSearch::Util::BitVector->new( capacity => $reader->max_doc );

    my $collector = KinoSearch::Search::HitCollector->new_bit_coll(
        bit_vector => $bits );

    my $searcher = KinoSearch::Searcher->new( reader => $reader );

    my $query
        = KinoSearch::Search::MatchFieldQuery->new( field => $self->{field} );

    $searcher->collect(
        query     => $query,
        filter    => $self,
        collector => $collector,
    );

    return $bits;
}

sub make_collector {
    my ( $self, $inner_coll, $reader ) = @_;
    my $sort_cache = $reader->fetch_sort_cache( $self->{field} );

    my ( $lower, $upper ) = $self->_find_bounds($reader);

    return KinoSearch::Search::HitCollector->new_range_coll(
        lower_bound => $lower,
        upper_bound => $upper,
        sort_cache  => $sort_cache,
        collector   => $inner_coll,
    );
}

# Find term numbers that should match for a range filter, inclusive.
sub _find_bounds {
    my ( $self, $reader ) = @_;

    my $lower = $self->_find_lower_bound($reader);
    my $upper = $self->_find_upper_bound($reader);

    # if lower term is past the end of the list or the field isn't valid...
    if ( !defined $lower ) {
        # return bounds that don't match anything
        return ( -2, -2 );
    }

    return ( $lower, $upper );
}

# Determine the lowest term number that should match for a range filter
# against a particular IndexReader.
sub _find_lower_bound {
    my ( $self, $reader ) = @_;
    return 0 unless defined( $self->{lower_term} );
    my $lower;

    # get a terms iterator, pre-seeked to our lower term.
    my $low_term
        = KinoSearch::Index::Term->new( $self->{field}, $self->{lower_term} );
    my $low_list = $reader->look_up_term($low_term);

    # our iterator is either at the term or right after where it would be
    if ( defined $low_list ) {
        my $low_found = $low_list->get_term;

        if ( defined $low_found ) {
            # term isn't beyond the end of the list, so use term num
            $lower = $low_list->get_term_num;

            if ( $low_term->equals($low_found) ) {
                # we have an exact match...
                if ( !$self->{include_lower} ) {
                    # we're not including it, so exclude the current term num
                    $lower += 1;
                }
            }
        }
    }

    return $lower;
}

# Determine the highest term number that should match for a range filter
# against a particular IndexReader.
sub _find_upper_bound {
    my ( $self, $reader ) = @_;
    return $reader->max_doc unless defined( $self->{upper_term} );
    my $upper;

    # get a terms iterator, pre-seeked to our higher term.
    my $high_term
        = KinoSearch::Index::Term->new( $self->{field}, $self->{upper_term} );
    my $high_list = $reader->look_up_term($high_term);

    # our iterator is either at the term or right after where it would be
    if ( defined $high_list ) {
        my $hi_found = $high_list->get_term;

        # are we still within the list's range?
        if ( defined $hi_found ) {
            # yup, so start with the current term num as upper bound
            $upper = $high_list->get_term_num;

            # if iterator is at term...
            if ( $high_term->equals($hi_found) ) {
                if ( !$self->{include_upper} ) {
                    # matching term not included, so decrement bound
                    $upper -= 1;
                }
            }

            else {
                # Nope, iterator is just past our term.
                # If we have a list [ a b c ] and we seek to 'bb', we're
                # currently at 'c'.  We don't want 'c' in our results, so
                # decrement the the term num.
                $upper -= 1;
            }
        }
        # we're past the end of the list, so use the list size as upper bound
        else {
            $upper = $high_list->get_size;
        }
    }

    return $upper;
}

1;

__END__

=head1 NAME

KinoSearch::Search::RangeFilter - Filter search results by range of values.

=head1 SYNOPSIS

    my $filter = KinoSearch::Search::RangeFilter->new(
        field         => 'date',
        lower_term    => '2000-01-01',
        upper_term    => '2001-01-01',
        include_lower => 1,
        include_upper => 0, 
    );
    my $hits = $searcher->search(
        query  => $query,
        filter => $filter,
    );

=head1 DESCRIPTION 

RangeFilter allows you to limit search results to documents where the value
for a particular field falls within a given range.

=head1 METHODS

=head2 new

    my $filter = KinoSearch::Search::RangeFilter->new(
        field         => 'product_number', # required
        lower_term    => '003',            # see below
        upper_term    => '060',            # see below
        include_lower => 0,                # default 1
        include_upper => 0,                # default 1
    );

Constructor.  Takes 5 hash-style parameters; C<field> is required, as is at
least one of either C<lower_term> or C<upper_term>.

=over

=item *

B<field> - The name of a field which is C<indexed> but not C<analyzed>.

=item *

B<lower_term> - Text string for the lower bound.  If not supplied, all values
less than C<upper_term> will pass.

=item *

B<upper_term> - Text string for the upper bound. If not supplied, all values
greater than C<lower_term> will pass.

=item *

B<include_lower> - indicate whether docs which match C<lower_term> should be
included in the results.

=item *

B<include_upper> - indicate whether docs which match C<upper_term> should be
included in the results.

=back

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
