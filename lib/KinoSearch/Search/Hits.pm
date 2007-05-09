use strict;
use warnings;

package KinoSearch::Search::Hits;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # params/members
    searcher  => undef,
    query     => undef,
    filter    => undef,
    sort_spec => undef,

    # members
    highlighter => undef,
    score_docs  => undef,
    total_hits  => undef,
    tick        => undef,
);

BEGIN { __PACKAGE__->ready_get(qw( score_docs )) }

use KinoSearch::Highlight::Highlighter;

sub seek {
    my ( $self, $offset, $num_wanted ) = @_;
    my $searcher = $self->{searcher};

    confess('Usage: $hits->seek( OFFSET, NUM_WANTED );')
        unless @_ = 3;

    # set our pointer for the next call to fetch_hit_hashref
    $self->{tick} = $offset;

    # if the seek takes us within bounds, don't redo the search
    if ( defined $self->{score_docs}
        and @{ $self->{score_docs} } > $offset + $num_wanted )
    {
        return;
    }

    # collect enough to satisfy both the offset and the num wanted
    my $top_docs = $searcher->top_docs(
        num_wanted => $num_wanted + $offset,
        query      => $self->{query},
        filter     => $self->{filter},
        sort_spec  => $self->{sort_spec},
    );

    # store away score_docs and total_hits
    $self->{score_docs} = $top_docs->get_score_docs;
    $self->{total_hits} = $top_docs->get_total_hits;
}

sub total_hits {
    my $self = shift;
    confess("seek() must be called before total_hits()")
        unless defined $self->{total_hits};
    return $self->{total_hits};
}

sub fetch_hit_hashref {
    my $self     = shift;
    my $searcher = $self->{searcher};

    confess("seek() must be called before total_hits()")
        unless defined $self->{total_hits};

    # bail if there aren't any more *captured* hits
    return if ( $self->{tick} >= @{ $self->{score_docs} } );

    # get a score doc then increment counter
    my $score_doc = $self->{score_docs}[ $self->{tick}++ ];

    # lazily fetch stored fields
    my $hashref = $searcher->fetch_doc( $score_doc->get_doc_num );

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

A classic application would be paging through hits.  After the first 10 hits
are displayed, if the user wants to see more -- and there are more than 10
total hits -- the Hits object may seek() to an OFFSET of 10 and retrieve 10
more documents.  And so on.

=head1 METHODS

=head2 seek 

    $hits->seek( OFFSET, NUM_WANTED );

Position the Hits iterator at C<OFFSET> and capture C<NUM_WANTED> docs.

=head2 total_hits

    my $num_that_matched = $hits->total_hits;

Return the total number of documents which matched the query used to produce
the Hits object.  (This number is unlikely to match C<NUM_WANTED>.)

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

