package KinoSearch::Search::Searchable;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Search::Similarity;

our %instance_vars = __PACKAGE__->init_instance_vars( similarity => undef );

__PACKAGE__->ready_get_set(qw( similarity ));

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

Generate a Doc object, retrieving the stored fields from the invindex.

=end comment
=cut

sub fetch_doc { shift->abstract_death }

=begin comment

    my $doc_freq = $searchable->doc_freq($term);

Return the number of documents which contain this Term.  Used for calculating
Weights.

=end comment
=cut

sub doc_freq { shift->abstract_death }

# not sure these are needed (call $query->create_weight($searcher) instead)
sub create_weight { shift->unimplemented_death }
sub rewrite_query { shift->unimplemented_death }

# needed by MultiSearcher?
sub doc_freqs { shift->unimplemented_death }

sub close { }

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::Searchable - base class for searching an invindex

=head1 DESCRIPTION 

Abstract base class for objects which search an invindex.  The most prominent
subclass is KinoSearch::Searcher.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut

