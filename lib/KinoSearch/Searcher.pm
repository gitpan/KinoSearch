use strict;
use warnings;

package KinoSearch::Searcher;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Searchable );

our %instance_vars = (
    # inherited members
    schema => undef,

    # params/members
    invindex => undef,
    reader   => undef,

    # members
    folder       => undef,
    prune_factor => undef,
);

BEGIN {
    __PACKAGE__->ready_get(qw( reader ));
    __PACKAGE__->ready_get_set(qw( prune_factor ));
}

use KinoSearch::Index::IndexReader;
use KinoSearch::Search::HitCollector;
use KinoSearch::Search::TopDocCollector;
use KinoSearch::Search::ScoreDoc;
use KinoSearch::Search::SortCollector;
use KinoSearch::Search::TopDocs;
use KinoSearch::Search::BooleanQuery;

sub init_instance {
    my $self = shift;

    # require either invindex or reader
    if ( a_isa_b( $self->{reader}, 'KinoSearch::Index::IndexReader' ) ) {
        $self->{invindex} = $self->{reader}->get_invindex;
    }
    elsif ( a_isa_b( $self->{invindex}, 'KinoSearch::InvIndex' ) ) {
        $self->{reader} = KinoSearch::Index::IndexReader->open(
            invindex => $self->{invindex} );
    }
    else {
        confess("Either 'invindex' or 'reader' is required");
    }

    # extract schema and folder
    $self->{schema} = $self->{invindex}->get_schema;
    $self->{folder} = $self->{invindex}->get_folder;
}

sub top_docs {
    my $self          = shift;
    my $top_docs_args = \%KinoSearch::Search::Searchable::top_docs_args;
    confess kerror() unless verify_args( $top_docs_args, @_ );
    my %args = ( %$top_docs_args, @_ );

    my $collector;
    if ( $args{sort_spec} ) {
        my $collator
            = $args{sort_spec}->make_field_doc_collator( $self->{reader} );
        $collector = KinoSearch::Search::SortCollector->new(
            size     => $args{num_wanted},
            collator => $collator,
        );
    }
    else {
        $collector = KinoSearch::Search::TopDocCollector->new(
            size => $args{num_wanted} );
    }

    $self->collect(
        collector  => $collector,
        query      => $args{query},
        filter     => $args{filter},
        num_wanted => $args{num_wanted},
    );
    my $score_docs = $collector->get_hit_queue()->score_docs;

    my $max_score
        = @$score_docs
        ? $score_docs->[0]->get_score
        : 0;

    return KinoSearch::Search::TopDocs->new(
        score_docs => $score_docs,
        max_score  => $max_score,
        total_hits => $collector->get_total_hits,
    );
}

sub collect {
    my $self         = shift;
    my $collect_args = \%KinoSearch::Search::Searchable::collect_args;
    confess kerror() unless verify_args( $collect_args, @_ );
    my %args = ( %$collect_args, @_ );
    my $reader = $self->{reader};

    # wrap the collector if there's a filter
    my $collector = $args{collector};
    if ( defined $args{filter} ) {
        $collector = $args{filter}->make_collector( $collector, $reader );
    }

    # process prune_factor if supplied
    my $seg_starts;
    my $hits_per_seg = 2**31;
    if ( defined $self->{prune_factor} and defined $args{num_wanted} ) {
        my $prune_count = $self->{prune_factor} * $args{num_wanted};

        if ( $prune_count < $hits_per_seg ) {    # don't exceed I32_MAX
            $hits_per_seg = $prune_count;
            $seg_starts   = $reader->get_seg_starts;
        }
    }

    # accumulate hits into the HitCollector if the query is valid
    my $weight = $self->create_weight( $args{query} );
    my $scorer = $weight->scorer($reader);
    if ( defined $scorer ) {
        $scorer->collect(
            collector    => $collector,
            end          => $reader->max_doc,
            hits_per_seg => $hits_per_seg,
            seg_starts   => $seg_starts,
        );
    }
}

sub fetch_doc     { $_[0]->{reader}->fetch_doc( $_[1] ) }
sub fetch_doc_vec { $_[0]->{reader}->fetch_doc_vec( $_[1] ) }

sub max_doc { shift->{reader}->max_doc }

sub doc_freq {
    my ( $self, $term ) = @_;
    return $self->{reader}->doc_freq($term);
}

sub close {
    my $self = shift;
    $self->{reader}->close if $self->{close_reader};
}

1;

__END__

=head1 NAME

KinoSearch::Searcher - Execute searches.

=head1 SYNOPSIS

    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->read('/path/to/invindex'),
    );
    my $hits = $searcher->search( 
        query      => 'foo bar' 
        offset     => 0,
        num_wanted => 100,
    );

=head1 DESCRIPTION

Use the Searcher class to perform search queries against an invindex.  

Searcher's behavior is closely tied to that of
L<KinoSearch::Index::IndexReader>.  If any of these criteria apply to your
application, please consult IndexReader's documentation:

=over

=item * 

Persistent environment (e.g. mod_perl, FastCGI).

=item *

Index located on shared filesystem, such as NFS.

=item *

Incremental updates.

=back

=head1 METHODS

=head2 new

    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->read('/path/to/invindex'),
    );
    # or...
    my $searcher = KinoSearch::Searcher->new( reader => $reader );

Constructor.  Takes labeled parameters.  Either C<invindex> or C<reader> is
required.

=over

=item *

B<invindex> - an object which isa L<KinoSearch::InvIndex>.

=item *

B<reader> - an object which isa L<KinoSearch::Index::IndexReader>.

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
L<KinoSearch::Search::Query> or a query string.  If it's a query string, it
will be parsed using a QueryParser and a search will be performed against all
indexed fields in the InvIndex.  For more sophisticated searching, supply Query
objects, such as TermQuery and BooleanQuery.

=item *

B<offset> - The number of most-relevant hits to discard, typically used when
"paging" through hits N at a time.  Setting offset to 20 and num_wanted to 10
retrieves hits 21-30, assuming that 30 hits can be found.

=item *

B<num_wanted> - The number of hits you would like to see after C<offset> is
taken into account.  

=item *

B<filter> - An object which isa L<KinoSearch::Search::Filter>, such as a
L<QueryFilter|KinoSearch::Search::QueryFilter>,
L<RangeFilter|KinoSearch::Search::RangeFilter>, or
L<PolyFilter|KinoSearch::Search::PolyFilter>. Search results will
be limited to only those documents which pass through the filter.

=item *

B<sort_spec> - Must be a L<KinoSearch::Search::SortSpec>, which will affect
how results are ranked and returned.

=back

=head2 get_reader

    my $reader = $searcher->get_reader;

Return the Searcher's inner L<IndexReader|KinoSearch::Index::IndexReader>.

=head2 set_prune_factor

    $searcher->set_prune_factor(10);

Experimental, expert API. 

set_prune_factor() enables a lossy, heuristic optimization which can yield
significantly improved performance at the price of a small penalty in
relevance.  It is only useful when 1) you have a way of establishing an
absolute rank for all documents -- e.g.  page score, date of publication,
price; and 2) that primary ranking heavily influences which documents you want
returned.  Schema->pre_sort is used to control this sort order.

prune_factor is a multiplier which affects how prematurely searching a
particular segment terminates.  10 is a decent default.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.
