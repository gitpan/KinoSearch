package KinoSearch::Search::Query;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars( boost => 1, );

# get_boost and set_boost don't do anything useful yet.
__PACKAGE__->ready_get_set(qw( boost ));

=begin comment

    my $string = $query->to_string( $field_name );

Return a string representation of the query.  $field_name is a default field,
and affects how the string is generated -- for instance, if a TermQuery's
field matches $field_name, the field will be omitted, while if it doesn't
match, the field will be included in the string.

=end comment
=cut

sub to_string { shift->abstract_death }

=begin comment

    my $weight = $query->create_weight($searcher);

Only low-level Queries which rewrite themselves implement this method.

=end comment
=cut

sub create_weight { shift->abstract_death }

# Derive a weight for a high-level query.
sub to_weight {    # in Lucene, this method is simply "weight"
    my ( $self, $searcher ) = @_;
    my $rewritten_self = $searcher->rewrite($self);
    my $weight         = $rewritten_self->create_weight($searcher);
    my $sum            = $weight->sum_of_squared_weights;
    my $sim            = $self->get_similarity($searcher);
    my $norm           = $sim->query_norm($sum);
    $weight->normalize($norm);
    return $weight;
}

=begin comment

    my $rewritten_query = $query->rewrite( $index_reader );

Called by high-level Queries that wish to reformulate themselves as
agglomerations of low-level queries.

=end comment
=cut

sub rewrite { return shift }

=begin comment

my @terms = $query->extract_terms;

Return all the Terms within this query.

=end comment
=cut

sub extract_terms { shift->abstract_death }

# These are used by MultiSearcher.
sub combine               { shift->todo_death }
sub merge_boolean_queries { shift->todo_death }

# return the Similarity implementation used by the Query.
sub get_similarity {
    my ( $self, $searcher ) = @_;
    # This can be overriden in subclasses, allowing alternative Sims.
    return $searcher->get_similarity;
}

sub clone { shift->todo_death }

1;

__END__

=head1 NAME

KinoSearch::Search::Query - base class for search queries

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Base class for queries to be performed against an invindex.
L<TermQuery|KinoSearch::Search::TermQuery> is one example.

=begin devdocs

A Query in KinoSearch is a highly abstracted representation.  It must be
transformed in several ways before the index is actually consulted to see how
documents score against it.

First, a Query must be "rewritten", a task that falls to the searcher.
Rewriting something as simple as a TermQuery just means returning the original
object; other more complex Queries, e.g. the as-yet-unimplemented SpanQueries,
may get transformed into collections of simpler queries -- such as
TermQueries.

Next, a Weight must be derived from a Query.  The role of a Weight is to hold
all data which changes as the search gets processed -- allowing still-pristine
Query objects to be reused later.

The Weight object is used to derive a Scorer.  The scorer iterates over the
documents which match the query, producing doc_num => score pairs.  These
pairs are are processed by a HitCollector.  

Different types of HitCollectors yield different results.

Here's another way of looking at the divided responsibilities:
    
    # 1. Searcher-dependent info belongs in the Weight.
    # 2. IndexReader-dependent info belongs in the Scorer.

=end devdocs

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=cut

