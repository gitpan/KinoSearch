use strict;
use warnings;

package KinoSearch::Searcher;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Searchable );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # params/members
        invindex => undef,
        # members
        folder      => undef,
        ix_reader   => undef,
        sort_caches => {},
    );
    __PACKAGE__->ready_get(qw( ix_reader ));
}

use KinoSearch::Index::IndexReader;
use KinoSearch::Search::Hits;
use KinoSearch::Search::HitCollector;
use KinoSearch::Search::TopDocCollector;
use KinoSearch::Search::ScoreDoc;
use KinoSearch::Search::SortCollector;
use KinoSearch::Search::TopDocs;
use KinoSearch::QueryParser::QueryParser;
use KinoSearch::Search::BooleanQuery;

sub init_instance {
    my $self = shift;

    # verify InvIndex and extract schema and folder
    my $invindex = $self->{invindex};
    confess("Missing required arg 'invindex'")
        unless a_isa_b( $invindex, "KinoSearch::InvIndex" );
    $self->{schema} = $invindex->get_schema;
    $self->{folder} = $invindex->get_folder;

    # get an IndexReader
    $self->{ix_reader}
        = KinoSearch::Index::IndexReader->new( invindex => $invindex );
}

my %search_args = (
    query      => undef,
    filter     => undef,
    sort_spec  => undef,
    offset     => 0,
    num_wanted => 10,
);

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

my %search_top_docs_args = (
    query      => undef,
    filter     => undef,
    sort_spec  => undef,
    num_wanted => undef,
);

sub search_top_docs {
    my $self = shift;
    confess kerror() unless verify_args( \%search_top_docs_args, @_ );
    my %args = ( %search_top_docs_args, @_ );

    my $weight = $self->create_weight( $args{query} );

    my $collector;
    if ( $args{sort_spec} ) {
        my $collator
            = $args{sort_spec}->make_field_doc_collator( $self->{ix_reader} );
        $collector = KinoSearch::Search::SortCollector->new(
            size     => $args{num_wanted},
            collator => $collator,
        );
    }
    else {
        $collector = KinoSearch::Search::TopDocCollector->new(
            size => $args{num_wanted} );
    }

    $self->search_hit_collector(
        hit_collector => $collector,
        weight        => $weight,
        filter        => $args{filter},
    );
    my $score_docs = $collector->get_hit_queue()->score_docs;

    my $max_score =
          @$score_docs
        ? $score_docs->[0]->get_score
        : 0;

    return KinoSearch::Search::TopDocs->new(
        score_docs => $score_docs,
        max_score  => $max_score,
        total_hits => $collector->get_total_hits,
    );
}

# Search for the query string against all indexed fields
sub _prepare_simple_search {
    my ( $self, $query_string ) = @_;
    my $query_parser = KinoSearch::QueryParser::QueryParser->new(
        schema => $self->{schema}, );
    return $query_parser->parse($query_string);
}

my %search_hit_collector_args = (
    hit_collector => undef,
    weight        => undef,
    filter        => undef,
);

sub search_hit_collector {
    my $self = shift;
    confess kerror() unless verify_args( \%search_hit_collector_args, @_ );
    my %args = ( %search_hit_collector_args, @_ );

    # wrap the collector if there's a filter
    my $collector = $args{hit_collector};
    if ( defined $args{filter} ) {
        $collector = $args{filter}->make_collector( $collector, $self );
    }

    # accumulate hits into the HitCollector if the query is valid
    my $scorer = $args{weight}->scorer( $self->{ix_reader} );
    if ( defined $scorer ) {
        $scorer->score_batch(
            hit_collector => $collector,
            end           => $self->{ix_reader}->max_doc,
        );
    }
}

sub fetch_doc     { $_[0]->{ix_reader}->fetch_doc( $_[1] ) }
sub fetch_doc_vec { $_[0]->{ix_reader}->fetch_doc_vec( $_[1] ) }

sub max_doc { shift->{ix_reader}->max_doc }

sub doc_freq {
    my ( $self, $term ) = @_;
    return $self->{ix_reader}->doc_freq($term);
}

sub create_weight {
    my ( $self, $query ) = @_;
    return $query->to_weight($self);
}

sub close {
    my $self = shift;
    $self->{ix_reader}->close if $self->{close_reader};
}

1;

__END__

=head1 NAME

KinoSearch::Searcher - Execute searches.

=head1 SYNOPSIS

    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->open('/path/to/invindex'),
    );
    my $hits = $searcher->search( 
        query      => 'foo bar' 
        offset     => 0,
        num_wanted => 100,
    );


=head1 DESCRIPTION

Use the Searcher class to perform queries against an invindex.  

=head1 METHODS

=head2 new

    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->open('/path/to/invindex'),
    );

Constructor.  Takes one labeled parameter.

=over

=item *

B<invindex> - an object which isa L<KinoSearch::InvIndex>.

=back

=head2 search

    my $hits = $searcher->search( 
        query      => $query,     # required
        offset     => 20,         # default: 0
        num_wanted => 10,         # default: 10
        filter     => $filter,    # default: undef (no filtering)
        sort_spec  => $sort_spec, # default: undef (sort by relevance)
    );

Process a search and return a L<Hits|KinoSearch::Search::Hits> object.
search() expects labeled hash-style parameters.

=over

=item *

B<query> - Can be either an object which subclasses
L<KinoSearch::Search::Query>, or a UTF-8 query string.  If it's a query
string, it will be parsed using a QueryParser and a search will be performed
against all indexed fields in the InvIndex.  For more sophisticated searching,
supply Query objects, such as TermQuery and BooleanQuery.

=item *

B<offset> - The number of most-relevant hits to discard, typically used when
"paging" through hits N at a time.  Setting offset to 20 and num_wanted to 10
retrieves hits 21-30, assuming that 30 hits can be found.

=item *

B<num_wanted> - The number of hits you would like to see after offset is taken
into account.  

=item *

B<filter> - Must be a L<KinoSearch::Search::QueryFilter>.  Search results will
be limited to only those documents which pass through the filter.

=item *

B<sort_spec> - Must be a L<KinoSearch::Search::SortSpec>, which will affect
how results are ranked and returned.

=back

=head1 Caching a Searcher

When a Searcher is created, a small portion of the InvIndex is loaded into
memory.  For large document collections, this startup time may become
noticable, in which case reusing the searcher is likely to speed up your
search application.  Caching a Searcher is especially helpful when running a
high-activity app under mod_perl.

Searcher objects always represent a snapshot of an InvIndex as it existed when
the Searcher was created.  If you want the search results to reflect
modifications to an InvIndex, you must create a new Searcher after the update
process completes.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.
