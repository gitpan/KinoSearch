use strict;
use warnings;

package KinoSearch::Search::Searchable;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # members
        schema => undef,
    );
    __PACKAGE__->ready_get(qw( schema ));
}

=begin comment

    my $hits = $searchable->search($query_string);

    my $hits = $searchable->search(
        query     => $query,
        filter    => $filter,
        sort_spec => $sort_spec,
    );

=end comment
=cut

sub search { shift->abstract_death }

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

=begin comment

    my $sim       = $searchable->get_similarity;
    my $field_sim = $searchable->get_similarity($field_name);

Retrieve a Similarity object.  If a field name is included, retrieve the
Similarity instance for that field only.

=end comment
=cut

sub get_similarity {
    my ( $self, $field_name ) = @_;

    # prevent undef warning -- we always want to return a similarity
    $field_name ||= "";

    return $self->{schema}->fetch_sim($field_name);
}

# Factory method for turning a Query into a Weight.
sub create_weight { shift->abstract_death }

sub doc_freqs {
    my ( $self, $terms ) = @_;
    my @doc_freqs = map { $self->doc_freq($_) } @$terms;
    return \@doc_freqs;
}

sub close { }

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::Searchable - Base class for searching an InvIndex.

=head1 DESCRIPTION 

Abstract base class for objects which search an InvIndex.  The most prominent
subclass is KinoSearch::Searcher.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

