use strict;
use warnings;

package KinoSearch::Search::Query;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        boost => 1,
    );
    __PACKAGE__->ready_get_set(qw( boost ));
}

=begin comment

    my $string = $query->to_string( $field_name );

Return a string representation of the query.  $field_name is a default field,
and affects how the string is generated -- for instance, if a TermQuery's
field matches $field_name, the field will be omitted, while if it doesn't
match, the field will be included in the string.

=end comment
=cut

sub to_string { shift->abstract_death }

# Derive a weight for a high-level query.
sub to_weight {    # in Lucene, this method is simply "weight"
    my ( $self, $searcher ) = @_;
    my $weight = $self->create_weight($searcher);
    my $sum    = $weight->sum_of_squared_weights;
    my $sim    = $self->get_similarity($searcher);
    my $norm   = $sim->query_norm($sum);
    $weight->normalize($norm);
    return $weight;
}

=begin comment

my @terms = $query->extract_terms;

Return all the Terms within this query.

=end comment
=cut

sub extract_terms { shift->abstract_death }

# return the Similarity implementation used by the Query.
sub get_similarity {
    my ( $self, $searcher, $field_name ) = @_;
    # This can be overriden in subclasses, allowing alternative Sims.
    return defined $field_name
        ? $searcher->get_similarity($field_name)
        : $searcher->get_similarity;
}

sub clone { shift->todo_death }

1;

__END__

=head1 NAME

KinoSearch::Search::Query - Base class for search queries.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Base class for queries to be performed against an InvIndex.
L<TermQuery|KinoSearch::Search::TermQuery> is one example.

=head1 METHODS

=head2 set_boost get_boost

    $term_query_a->set_boost(2);
    $boolean_query->add_clause( query => $term_query_a, occur => 'SHOULD' );
    $boolean_query->add_clause( query => $term_query_b, occur => 'SHOULD' );

The boost of any Query is 1.0 by default. Setting boost to a number greater
than one increases a Query's relative contribution to a score, and setting
boost to a lower number decreases the contribution.

=begin devdocs

A Query in KinoSearch is a highly abstracted representation.  It must be
transformed before the index is actually consulted to see how documents score
against it.

First, a Weight must be derived from a Query.  The role of a Weight is to hold
all data which changes as the search gets processed -- allowing still-pristine
Query objects to be reused later.

Next, the Weight object is used to derive a Scorer.  The scorer iterates over
the documents which match the query, producing doc_num => score pairs.  These
pairs are are processed by a HitCollector.  

Different types of HitCollectors yield different results.

Here's another way of looking at the divided responsibilities:
    
    # 1. Searcher-dependent info belongs in the Weight.
    # 2. IndexReader-dependent info belongs in the Scorer.

=end devdocs

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
