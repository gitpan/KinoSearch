use strict;
use warnings;

package KinoSearch::Search::RangeFilter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        field         => undef,
        lower_term    => undef,
        upper_term    => undef,
        include_lower => undef,
        include_upper => undef,
    );
}

use KinoSearch::Search::HitCollector;

sub init_instance {
    my $self = shift;

    for (qw( field lower_term upper_term include_lower include_upper )) {
        confess("Missing required parameter $_")
            unless defined $self->{$_};
    }
}

sub make_collector {
    my ( $self, $inner_coll, $searcher ) = @_;
    confess("Can't get an ix_reader") unless $searcher->can('get_ix_reader');
    my $ix_reader  = $searcher->get_ix_reader;
    my $sort_cache = $ix_reader->fetch_sort_cache( $self->{field} );

    my $low_term
        = KinoSearch::Index::Term->new( $self->{field}, $self->{lower_term} );
    my $low_list = $ix_reader->field_terms($low_term);
    my $lower = -2;    # outside the range of IntMap's -1 default
    if ( defined $low_list ) {
        my $low_found = $low_list->get_term;
        if ( defined $low_found ) {
            $lower = $low_list->get_term_num;
            if ( $low_term->equals($low_found) ) {
                if ( !$self->{include_lower} ) {
                    $lower += 1;
                }
            }
        }
    }

    my $high_term
        = KinoSearch::Index::Term->new( $self->{field}, $self->{upper_term} );
    my $high_list = $ix_reader->field_terms($high_term);
    my $upper     = -2;
    if ( defined $high_list ) {
        my $hi_found = $high_list->get_term;
        if ( defined $hi_found ) {
            $upper = $high_list->get_term_num;
            if ( $high_term->equals($hi_found) ) {
                if ( !$self->{include_upper} ) {
                    $upper -= 1;
                }
            }
            else {
                if ( !$self->{include_upper} ) {
                    $upper -= 1;
                }
                else {
                    $upper += 1;
                }
            }
        }
    }

    return KinoSearch::Search::HitCollector->new_range_coll(
        lower_bound   => $lower,
        upper_bound   => $upper,
        sort_cache    => $sort_cache,
        hit_collector => $inner_coll,
    );
}

1;

__END__

=head1 NAME

KinoSearch::Search::RangeFilter - Filter search results by range of values.

=head1 SYNOPSIS

    my $filter = KinoSearch::Search::RangeFilter->new(
        field         => 'date',
        lower_term    => '2000-01-01',
        upper_term    => '9999-01-01',
        include_lower => 1,
        include_upper => 1, 
    );
    my $hits = $searcher->search(
        query  => $query,
        filter => $filter,
    );

=head1 DESCRIPTION 

Range filter allows you to limit search results to documents where the value
for a particular field falls within a given range.

=head1 METHODS

=head2 new

    my $filter = KinoSearch::Search::RangeFilter->new(
        field         => 'product_number', # required
        lower_term    => '003',            # required
        upper_term    => '060',            # required
        include_lower => 1,                # required
        include_upper => 1,                # required
    );

Constructor.  Takes 5 hash-style parameters, all of which are required.

=over

=item *

B<field> - The name of a field which is C<indexed> but not C<analyzed>.

=item *

B<lower_term> - Text string for the lower bound.

=item *

B<lower_term> - Text string for the upper bound.

=item *

B<include_lower> - indicate whether docs which match the lower bound should be
included in the results.

=item *

B<include_upper> - indicate whether docs which match the upper bound should be
included in the results.

=back

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
