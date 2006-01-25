package KinoSearch::Search::Hits;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # params/members
    searcher  => undef,
    query     => undef,
    filter    => undef,
    sort_spec => undef,

    # members
    weight    => undef,
    hit_queue => undef,

    hit_docs   => undef,
    pointer    => undef,
    total_hits => undef,
    score_norm => 1,

);

sub init_instance {
    my $self = shift;

    croak("required parameter 'query' not supplied")
        unless $self->{query};
    croak("required parameter 'searcher' not supplied")
        unless $self->{searcher};

    # turn the Query into a Weight (so the Query won't get mussed)
    $self->{weight} = $self->{query}->to_weight( $self->{searcher} );
}

sub seek {
    my ( $self, $start_offset, $num_wanted ) = @_;
    croak('Usage: $hits->seek( START, NUM_TO_RETRIEVE );')
        unless @_ = 3;
    $self->{pointer} = $start_offset;

    # collect enough to satisfy both the offset and the num wanted
    $num_wanted += $start_offset;

    # execute the search!
    @{$self}{qw( hit_queue total_hits )} = $self->{searcher}->search_hit_queue(
        num_wanted => $num_wanted,
        weight     => $self->{weight},
        filter     => $self->{filter},
        sort_spec  => $self->{sort_spec},
    );

    # turn the HitQueue into HitDocs
    $self->{hit_docs}   = $self->{hit_queue}->hit_docs;
}

sub total_hits {
    my $self = shift;
    croak("must seek before calling total_hits")
        unless defined $self->{total_hits};
    return $self->{total_hits};
}

sub fetch_hit_hashref {
    my $self = shift;
    croak("must seek before calling fetch_hit_hashref")
        unless defined $self->{total_hits};

    # bail if there aren't any more *captured* hits
    return unless exists $self->{hit_docs}[ $self->{pointer} ];

    # lazily fetch stored fields
    my $hit_doc = $self->{hit_docs}[ $self->{pointer}++ ];
    $hit_doc->set_doc( $self->{searcher}->fetch_doc( $hit_doc->get_doc_num ) )
        unless defined $hit_doc->get_doc;
    my $hashref = $hit_doc->get_doc()->to_hashref;

    return wantarray
        ? ( $hashref, $hit_doc->get_score )
        : $hashref;
}

1;

=head1 NAME

KinoSearch::Search::Hits - access search results

=head1 SYNOPSIS

    my $hits = $searcher->search($query);
    $hits->seek(0, 10);
    my $total_hits = $hits->total_hits;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        print "$hit->{title}\n";
    }

=head1 DESCRIPTION

Hits objects are used to access the results of a search.  

A classic application would be paging through hits.  The first time, seek to a
START of 0, and retrieve 10 documents.  If the user wants to see more -- and
there are more than 10 total hits -- seek to a START of 10, and retrieve 10
more documents.  And so on.

=head1 METHODS

=head2 seek 

    $hits->seek( START, NUM_TO_RETRIEVE );

Position the Hits iterator at START, and capture NUM_TO_RETRIEVE docs.

seek I<must> be called before anything else.

=head2 total_hits

Return the total number of documents which matched the query used to produce
the Hits object.  (This number is unlikely to match NUM_TO_RETRIEVE.)

=head2 fetch_hit_hashref

    while ( my $hit = $hits->fetch_hit_hashref ) {
        # ...
    }
    
    # or...
    while ( my ( $hit, $score ) = $hits->fetch_hit_hashref ) {
        # ...
    }

Return the next hit or hit/score pairing.  The hit is retrieved as a hashref,
with the field names as keys and the field values as values.  In list context,
fetch_hit_hashref returns the hashref and a floating point score.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=cut

