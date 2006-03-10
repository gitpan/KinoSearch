package KinoSearch::Searcher;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Searchable );

use KinoSearch::Store::FSInvIndex;
use KinoSearch::Index::IndexReader;
use KinoSearch::Search::Hits;
use KinoSearch::Search::HitCollector;
use KinoSearch::Search::Similarity;
use KinoSearch::QueryParser::QueryParser;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Analysis::Analyzer;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # params/members
    invindex => undef,
    analyzer => KinoSearch::Analysis::Analyzer->new,
    # members
    reader       => undef,
    close_reader => 0,       # not implemented yet
);

__PACKAGE__->ready_get(qw( reader ));

sub init_instance {
    my $self = shift;

    $self->{similarity} = KinoSearch::Search::Similarity->new;

    if ( !defined $self->{reader} ) {
        # confirm or create an InvIndex object
        my $invindex;
        if ( blessed( $self->{invindex} )
            and $self->{invindex}->isa('KinoSearch::Store::InvIndex') )
        {
            $invindex = $self->{invindex};
        }
        elsif ( defined $self->{invindex} ) {
            $invindex = $self->{invindex}
                = KinoSearch::Store::FSInvIndex->new(
                create => $self->{create},
                path   => $self->{invindex},
                );
        }
        else {
            croak("valid 'reader' or 'invindex' must be supplied");
        }

        # now that we have an invindex, get a reader for it
        $self->{reader} = KinoSearch::Index::IndexReader->new(
            invindex => $self->{invindex} );
    }
}

my %search_args = (
    query    => undef,
    filter   => undef,
    num_docs => undef,
);

sub search {
    my $self = shift;
    my %args =
        @_ == 1
        ? ( %search_args, query => $_[0] )
        : ( %search_args, @_ );
    verify_args( \%search_args, %args );
    if ( !a_isa_b( $args{query}, 'KinoSearch::Search::Query' ) ) {
        $args{query} = $self->_prepare_simple_search( $args{query} );
    }
    return KinoSearch::Search::Hits->new( searcher => $self, %args );
}

sub _prepare_simple_search {
    my ( $self, $query_string ) = @_;

    my $super_query = KinoSearch::Search::BooleanQuery->new;

    my $indexed_field_names
        = $self->{reader}->get_field_names( indexed => 1 );
    for my $field_name (@$indexed_field_names) {
        my $query_parser = KinoSearch::QueryParser::QueryParser->new(
            default_field => $field_name,
            analyzer      => $self->{analyzer},
        );
        my $sub_query = $query_parser->parse($query_string);
        $super_query->add_clause(
            query => $sub_query,
            occur => 'SHOULD',
        );
    }
    return $super_query;
}

my %search_hit_queue_args = (
    weight     => undef,
    filter     => undef,
    num_wanted => undef,
    sort_spec  => undef,
);

sub search_hit_queue {
    my $self = shift;
    verify_args( \%search_hit_queue_args, @_ );
    my %args = ( %search_hit_queue_args, @_ );

    my $scorer = $args{weight}->scorer( $self->{reader} );

    my $hc = KinoSearch::Search::HitQueueCollector->new(
        size => $args{num_wanted}, );

    # accumulate hits into the HitCollector if the query is valid
    if ( defined $scorer ) {
        $scorer->score_batch(
            hit_collector => $hc,
            end           => $self->{reader}->max_doc,
        );
    }

    # return the HitQueue and the number of hits
    return ( $hc->get_storage, $hc->get_i );
}

sub fetch_doc { $_[0]->{reader}->fetch_doc( $_[1] ) }
sub max_doc   { shift->{reader}->max_doc }

sub doc_freq {
    my ( $self, $term ) = @_;
    return $self->{reader}->doc_freq($term);
}

sub create_weight {
    my ( $self, $query ) = @_;
    return $query->create_weight($self);
}

sub rewrite {
    my ( $self, $query ) = @_;
    my $reader = $self->{reader};
    while (1) {
        my $rewritten = $query->rewrite($reader);
        last if ( 0 + $rewritten == 0 + $query );
        $query = $rewritten;
    }
    return $query;
}

sub close {
    my $self = shift;
    $self->{reader}->close if $self->{close_reader};
}

1;

__END__

=head1 NAME

KinoSearch::Searcher - execute searches

=head1 SYNOPSIS

    my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new( 
        language => 'en',
    );

    my $searcher = KinoSearch::Searcher->new(
        invindex => $invindex,
        analyzer => $analyzer,
    );
    my $hits = $searcher->search( query => 'foo bar' );


=head1 DESCRIPTION

Use the Searcher class to perform queries against an invindex.  

=head1 METHODS

=head2 new

    my $searcher = KinoSearch::Searcher->new(
        invindex => $invindex,
        analyzer => $analyzer,
    );

Constructor.  Takes two labeled parameters, both of which are required.

=over

=item *

B<invindex> - can be either a path to an invindex, or a
L<KinoSearch::Store::InvIndex|KinoSearch::Store::InvIndex> object.

=item *

B<analyzer> - An object which subclasses
L<KinoSearch::Analysis::Analyer|KinoSearch::Analysis::Analyzer>, such as a
L<PolyAnalyzer|KinoSearch::Analysis::PolyAnalyzer>.  This B<must> be identical
to the Analyzer used at index-time, or the results won't match up.

=back

=head2 search

    my $hits = $searcher->search( query => $query );
        
Process a search and return a L<Hits|KinoSearch::Search::Hits> object.

search() expects labeled hash-style parameters.  At present, there is only
one: query.  It is likely that others will be added later.

=over

=item *

B<query> - Can be either an object which subclasses
L<KinoSearch::Search::Query|KinoSearch::Search::Query>, or a query string.  If
it's a query string, it will be parsed using a QueryParser and a search will
be performed against all indexed fields in the invindex.  For more sophisticated
searching, supply Query objects, such as TermQuery and BooleanQuery.

=back

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.
