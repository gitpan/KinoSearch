use strict;
use warnings;

package KinoSearch::Search::BooleanQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

our %instance_vars = (
    # inherited
    boost => 1.0,

    # members
    clauses          => undef,
    max_clause_count => 1024,
);

BEGIN {
    __PACKAGE__->ready_get(qw( clauses ));
}

use KinoSearch::Search::BooleanClause;

sub init_instance {
    my $self = shift;
    $self->{clauses} = [];
}

# Add an subquery tagged with boolean characteristics.
sub add_clause {
    my $self = shift;
    my $clause
        = @_ == 1
        ? shift
        : KinoSearch::Search::BooleanClause->new(@_);
    confess("not a BooleanClause")
        unless a_isa_b( $clause, 'KinoSearch::Search::BooleanClause' );
    confess("Too many clauses")
        if @{ $self->{clauses} } > $self->{max_clause_count};

    push @{ $self->{clauses} }, $clause;
}

sub extract_terms {
    my $self = shift;
    my @terms;
    for my $clause ( @{ $self->{clauses} } ) {
        push @terms, $clause->get_query()->extract_terms;
    }
    return @terms;
}

sub make_weight {
    my ( $self, $searcher ) = @_;
    return KinoSearch::Search::BooleanWeight->new(
        parent   => $self,
        searcher => $searcher,
    );
}

package KinoSearch::Search::BooleanWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

our %instance_vars = (
    # inherited
    searcher   => undef,
    parent     => undef,
    similarity => undef,

    # members
    sub_weights => undef,
);

use KinoSearch::Search::BooleanScorer;

sub init_instance {
    my $self = shift;

    # don't keep searcher around; it interferes with serialization
    my $searcher = delete $self->{searcher};

    # use the Schema's main Similarity
    $self->{similarity} = $searcher->get_schema->fetch_sim;

    # iterate over the clauses, creating a Weight for each one
    $self->{sub_weights} = [];
    for my $clause ( @{ $self->{parent}{clauses} } ) {
        my $sub_query = $clause->get_query;
        push @{ $self->{sub_weights} }, $sub_query->make_weight($searcher);
    }

    # make final preparations
    $self->perform_query_normalization($searcher);
}

sub get_value { shift->{parent}->get_boost }

sub sum_of_squared_weights {
    my $self = shift;

    my $sum = 0;
    $sum += $_->sum_of_squared_weights for @{ $self->{sub_weights} };

    # compound the weight of each sub-Weight
    $sum *= $self->{parent}->get_boost**2;

    return $sum;
}

sub normalize {
    my ( $self, $query_norm_factor ) = @_;
    # override normalization performed by individual clauses
    $_->normalize($query_norm_factor) for @{ $self->{sub_weights} };
}

sub scorer {
    my ( $self, $reader ) = @_;

    my $scorer = KinoSearch::Search::BooleanScorer->new(
        similarity => $self->{similarity}, );

    # add all the subscorers one by one
    my $clauses = $self->{parent}{clauses};
    my $i       = 0;
    for my $sub_weight ( @{ $self->{sub_weights} } ) {
        my $clause    = $clauses->[ $i++ ];
        my $subscorer = $sub_weight->scorer($reader);
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

=head1 NAME

KinoSearch::Search::BooleanQuery - Match boolean combinations of Queries.

=head1 SYNOPSIS

    my $bool_query = KinoSearch::Search::BooleanQuery->new;
    $bool_query->add_clause( query => $term_query, occur => 'MUST' );
    my $hits = $searcher->search( query => $bool_query );

=head1 DESCRIPTION 

BooleanQueries are super-Query objects which match boolean combinations of
other Queries.

One way of producing a BooleanQuery is to feed a query string along the lines
of C<this AND NOT that> to a
L<QueryParser|KinoSearch::QueryParser> object:
    
    my $bool_query = $query_parser->parse( 'this AND NOT that' );

It's also possible to achieve the same end by manually constructing the query
piece by piece:

    my $bool_query = KinoSearch::Search::BooleanQuery->new;
    
    my $this_query = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'bodytext', 'this' ),
    );
    $bool_query->add_clause( query => $this_query, occur => 'MUST' );

    my $that_query = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'bodytext', 'that' ),
    );
    $bool_query->add_clause( query => $that_query, occur => 'MUST_NOT' );

QueryParser objects and hand-rolled Queries can work together:

    my $general_query = $query_parser->parse($q);
    my $news_only     = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'category', 'news' );
    );
    $bool_query->add_clause( query => $general_query, occur => 'MUST' );
    $bool_query->add_clause( query => $news_only,     occur => 'MUST' );

=head1 METHODS

=head2 new

    my $bool_query = KinoSearch::Search::BooleanQuery->new;

Constructor. Takes no arguments.

=head2 add_clause

    $bool_query->add_clause(
        query => $query, # required
        occur => 'MUST', # default: 'SHOULD'
    );

Add a clause to the BooleanQuery.  Takes hash-style parameters:

=over

=item *

B<query> - an object which belongs to a subclass of
L<KinoSearch::Search::Query>.

=item *

B<occur> - must be one of three possible values: 'SHOULD', 'MUST', or
'MUST_NOT'.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
