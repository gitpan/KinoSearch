use strict;
use warnings;

package KinoSearch::Search::Weight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor arg (only!)
    searcher => undef,

    # constructor args / members
    parent => undef,

    # members
    similarity => undef,
);

# Return the Query that the Weight was derived from.
sub get_query { shift->{parent} }

# Return the Weight's numerical value.
sub get_value { shift->abstract_death }

=begin comment

Take a newly minted Weight object and apply query-specific normalization
factors.  Once this method completes, the Weight is ready for use.  It
should be called by every Weight subclass at the end of construction.

For a TermQuery, the scoring forumla is approximately:

   ( tf_d * idf_t / norm_d ) * ( tf_q * idf_t / norm_q ) 

This routine is theoretically concerned with the second half of that formula;
what it actually means depends on how the relevant Weight and Similarity
methods are implemented.
 
=end comment
=cut 

sub perform_query_normalization {
    my ( $self, $searcher ) = @_;
    my $sim = $self->{similarity};

    my $factor = $self->sum_of_squared_weights;    # factor = ( tf_q * idf_t )
    $factor = $sim->query_norm($factor);           # factor /= norm_q
    $self->normalize($factor);                     # impact *= factor
}

# Compute and return a raw weighting factor for the Query, which is used as
# part of the query normalization process.
sub sum_of_squared_weights { shift->abstract_death }

# Normalize the Weight/Query, so that it produces more comparable numbers in
# context of other Weights/Queries.
sub normalize { shift->abstract_death }

=begin comment

    my $scorer = $weight->scorer( $index_reader );

Return a subclass of scorer, primed with values and ready to crunch numbers.

=end comment
=cut

sub scorer { shift->abstract_death }

=begin comment

    my $explanation = $weight->explain( $index_reader, $doc_num );

Explain how a document scores.

=end comment
=cut

sub explain { shift->todo_death }

sub to_string {
    my $self = shift;
    return "weight(" . $self->get_query->to_string . ")";
}

1;

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::Weight - Searcher-dependent transformation of a Query.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

The main purpose of Weight is to enable reuse of Query objects.  During the
process of assembling a Scorer, different components may need to be assigned
multipliers -- that is, weights.  Assigning these multipliers to Query objects
directly could affect other, unrelated queries, so we create derivative
objects to hold the weighted queries: Weights.

In one sense, a Weight is the weight of a Query object.  Conceptually, a
Query's "weight" ought to be a single number: a coefficient... and indeed,
eventually a Weight object gets turned into a $weight_value.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

