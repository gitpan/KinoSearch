use strict;
use warnings;

package KinoSearch::Search::Searchable;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # members
    schema => undef,
);

BEGIN { __PACKAGE__->ready_get(qw( schema )) }

use KinoSearch::Search::Hits;
use KinoSearch::QueryParser::QueryParser;

our %search_args = (
    query      => undef,
    filter     => undef,
    sort_spec  => undef,
    offset     => 0,
    num_wanted => 10,
);

# Returns a Hits object which calls top_docs().
sub search {
    my $self = shift;
    confess kerror() unless verify_args( \%search_args, @_ );
    my %args = ( %search_args, @_ );

    # turn a query string into a query against all fields
    if ( !a_isa_b( $args{query}, 'KinoSearch::Search::Query' ) ) {
        $args{query} = $self->_prepare_simple_search( $args{query} );
    }

    # get a Hits object, and perform the search
    my $hits = KinoSearch::Search::Hits->new(
        searcher  => $self,
        query     => $args{query},
        filter    => $args{filter},
        sort_spec => $args{sort_spec},
    );
    $hits->seek( $args{offset}, $args{num_wanted} );
    return $hits;
}

# Search for the query string against all indexed fields
sub _prepare_simple_search {
    my ( $self, $query_string ) = @_;
    my $query_parser = KinoSearch::QueryParser::QueryParser->new(
        schema => $self->{schema}, );
    return $query_parser->parse($query_string);
}

=begin comment

    $searcher->collect(
        num_wanted => $num_wanted,
        collector  => $collector,
        query      => $query,
        filter     => $filter,
    );

Iterate over hits, feeding them into a HitCollector.

=end comment
=cut

our %collect_args = (
    collector  => undef,
    query      => undef,
    filter     => undef,
    num_wanted => undef,
);

sub collect { shift->abstract_death }

=begin  comment

    my $top_docs = $searchable->top_docs(
        query      => $query,
        num_wanted => $num_wanted,
        filter     => $filter,
        sort_spec  => $sort_spec,
    );

Return a TopDocs object with up to num_wanted hits.

Not all subclasses will allow the filter or the sort_spec.

=end comment 
=cut

our %top_docs_args = (
    query      => undef,
    num_wanted => undef,
    filter     => undef,
    sort_spec  => undef,
);

sub top_docs { shift->abstract_death }

=begin comment

    my $explanation = $searchable->explain( $weight, $doc_num );

Provide an Explanation for how the document represented by $doc_num scored
agains $weight.  Useful for probing the guts of Similarity.

=end comment
=cut

sub explain { shift->todo_death }

=begin comment

    my $doc_num = $searchable->max_doc;

Return one larger than the largest doc_num.

=end comment
=cut

sub max_doc { shift->abstract_death }

=begin comment

    my $doc =  $searchable->fetch_doc($doc_num);

Retrieve stored fields as a hashref.

=end comment
=cut

sub fetch_doc { shift->abstract_death }

=begin comment

    my $doc_vector =  $searchable->fetch_doc_vec($doc_num);

Generate a DocVector object from the relevant term vector files.

=end comment
=cut

sub fetch_doc_vec { shift->abstract_death }

=begin comment

    my $doc_freq = $searchable->doc_freq($term);

Return the number of documents which contain this Term.  Used for calculating
Weights.

=end comment
=cut

sub doc_freq { shift->abstract_death }

sub doc_freqs {
    my ( $self, $terms ) = @_;
    my @doc_freqs = map { $self->doc_freq($_) } @$terms;
    return \@doc_freqs;
}

# Factory method for turning a Query into a Weight.
sub create_weight {
    my ( $self, $query ) = @_;
    return $query->make_weight($self);
}

sub close { }

1;

__END__

=head1 Name

KinoSearch::Search::Searchable - Base class for searchers.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION 

Abstract base class for objects which search.  Subclasses include
L<KinoSearch::Searcher>, L<KinoSearch::Search::MultiSearcher>, and
L<KinoSearch::Search::SearchClient>.

=head1 METHODS

=head2 search

See L<KinoSearch::Searcher>'s API docs.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
