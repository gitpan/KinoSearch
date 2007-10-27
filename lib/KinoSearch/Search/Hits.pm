use strict;
use warnings;

package KinoSearch::Search::Hits;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # required params
    query    => undef,
    searcher => undef,
    top_docs => undef,

    # params/members
    offset      => 0,
    highlighter => undef,
);

BEGIN { __PACKAGE__->ready_get_set(qw( offset )) }

sub init_instance {
    my $self = shift;

    confess "top_docs is mandatory" unless $self->{top_docs};
    confess "query is mandatory"    unless $self->{query};
    confess "searcher is mandatory" unless $self->{searcher};
}

sub total_hits {
    my $self = shift;
    return $self->{top_docs}->get_total_hits;
}

sub get_score_docs {
    my $self = shift;
    return $self->{top_docs}->get_score_docs;
}

sub fetch_hit_hashref {
    my ($self) = @_;

    # get a score doc then increment counter for next time
    my $score_doc = $self->get_score_docs->[ $self->{offset}++ ];

    # bail if there aren't any more *captured* hits
    return unless $score_doc;

    # lazily fetch stored fields
    my $searcher = $self->{searcher};
    my $hashref  = $searcher->fetch_doc( $score_doc->get_doc_num );

    # add score to hashref
    $hashref->{score} = $score_doc->get_score;

    # add highlights if wanted
    if ( defined $self->{highlighter} ) {
        my $doc_vector = $searcher->fetch_doc_vec( $score_doc->get_doc_num );
        $hashref->{excerpts} = $self->{highlighter}
            ->generate_excerpts( $hashref, $doc_vector );
    }

    return $hashref;
}

my %create_excerpts_defaults = ( highlighter => undef, );

sub create_excerpts {
    my $self = shift;
    confess kerror() unless verify_args( \%create_excerpts_defaults, @_ );
    my %args = ( %create_excerpts_defaults, @_ );

    $self->{highlighter} = $args{highlighter};
    $self->{highlighter}->set_terms( [ $self->{query}->extract_terms ] );
}

1;

=head1 NAME

KinoSearch::Search::Hits - Access search results.

=head1 SYNOPSIS

    my $hits = $searcher->search(
        query      => $query,
        offset     => 0,
        num_wanted => 10,
    );
    while ( my $hashref = $hits->fetch_hit_hashref ) {
        print "<p>$hashref->{title} <em>$hashref->{score}</em></p>\n";
    }

=head1 DESCRIPTION

Hits objects are iterators used to access the results of a search.

=head1 METHODS

=head2 total_hits

    my $num_that_matched = $hits->total_hits;

Return the total number of documents which matched the query used to produce
the Hits object.  Note that this is the total number of matches, not just the
number collected, and thus will rarely match C<NUM_WANTED>.

=head2 fetch_hit_hashref

    while ( my $hashref = $hits->fetch_hit_hashref ) {
        # ...
    }

Return the next hit as a hashref, with the field names as keys and the field
values as values.  An entry for C<score> will also be present, as will an
entry for C<excerpts> if create_excerpts() was called earlier.

=head2 create_excerpts

    my $highlighter = KinoSearch::Highlight::Highlighter->new;
    $highlighter->add_spec( field => 'body' );   
    $hits->create_excerpts( highlighter => $highlighter );

Use the supplied highlighter to generate excerpts.  See
L<KinoSearch::Highlight::Highlighter>.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
