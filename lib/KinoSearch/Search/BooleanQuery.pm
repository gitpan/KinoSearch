package KinoSearch::Search::BooleanQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

use KinoSearch::Search::BooleanClause;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args / members
    disable_coord => 0,
    # members
    clauses          => [],
    max_clause_count => 1024,
);

__PACKAGE__->ready_get(qw( clauses ));

# Add an subquery tagged with boolean characteristics.
sub add_clause {
    my $self   = shift;
    my $clause =
        @_ == 1
        ? shift
        : KinoSearch::Search::BooleanClause->new(@_);
    push @{ $self->{clauses} }, $clause;
    confess("not a BooleanClause")
        unless a_isa_b( $clause, 'KinoSearch::Search::BooleanClause' );
    confess("Too many clauses")
        if @{ $self->{clauses} } > $self->{max_clause_count};
}

sub get_similarity {
    my ( $self, $searcher ) = @_;
    if ( $self->{disable_coord} ) {
        confess "disable_coord not implemented yet";
    }
    return $searcher->get_similarity;
}

sub create_weight {
    my ( $self, $searcher ) = @_;
    return KinoSearch::Search::BooleanWeight->new(
        parent   => $self,
        searcher => $searcher,
    );

}

sub clone {
    my $self = shift;

    # remove then restore clauses in case some queries aren't clone-safe.
    my $clauses   = delete $self->{clauses};
    my $evil_twin = Clone::clone($self);
    $self->{clauses} = $clauses;

    # clone each Clause in turn
    my @cloned_clauses = map { $_->clone } @$clauses;
    $evil_twin->{clauses} = \@cloned_clauses;

    return $evil_twin;
}

package KinoSearch::Search::BooleanWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

use KinoSearch::Search::BooleanScorer;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members
    weights => [],
);

sub init_instance {
    my $self = shift;
    my ( $weights, $searcher ) = @{$self}{ 'weights', 'searcher' };

    $self->{similarity} = $self->{parent}->get_similarity($searcher);

    for my $clause ( @{ $self->{parent}{clauses} } ) {
        my $query = $clause->get_query;
        push @$weights, $query->create_weight($searcher);
    }
}

sub get_value { shift->{parent}->get_boost }

sub sum_of_squared_weights {
    my $self = shift;

    my $sum = 0;
    $sum += $_->sum_of_squared_weights for @{ $self->{weights} };

    # compound the weight of each sub-Weight
    $sum *= $self->{parent}->get_boost**2;

    return $sum;
}

sub normalize {
    my ( $self, $query_norm ) = @_;
    $_->normalize($query_norm) for @{ $self->{weights} };
}

sub scorer {
    my ( $self, $reader ) = @_;

    my $scorer = KinoSearch::Search::BooleanScorer->new(
        similarity => $self->{similarity}, );

    # add all the subscorers one by one
    my $clauses = $self->{parent}{clauses};
    my $i       = 0;
    for my $weight ( @{ $self->{weights} } ) {
        my $clause    = $clauses->[ $i++ ];
        my $subscorer = $weight->scorer($reader);
        if ( defined $subscorer ) {
            $scorer->add_subscorer( $subscorer, $clause->get_occur );
        }
        elsif ( $clause->is_required ) {
            # if any required clause fails, the whole thing fails
            return undef;
        }
    }
    return $scorer;
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::BooleanQuery - match boolean combinations of Queries

=head1 DESCRIPTION 

BooleanQueries are super-Query objects which match boolean combinations of
other Queries.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut

