use strict;
use warnings;

package KinoSearch::Search::MultiSearcher;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Searchable );

our %instance_vars = (
    # members / constructor args
    searchables => undef,

    # inherited members
    schema => undef,

    # members
    analyzers => undef,
    starts    => undef,
    max_doc   => undef,
);

use KinoSearch::Search::HitCollector;

sub init_instance {
    my $self        = shift;
    my $searchables = $self->{searchables};

    # confirm schema
    if ( !defined $self->{schema} ) {
        $self->{schema} = $self->{searchables}[0]->get_schema;
    }
    confess("required parameter 'schema'")
        unless a_isa_b( $self->{schema}, "KinoSearch::Schema" );

    # confirm that all searchables use the same schema
    my $orig = ref $self->{schema};
    for (@$searchables) {
        my $candidate = ref( $_->get_schema );
        next if $candidate eq $orig;
        confess("Conflicting schemas: '$orig' '$candidate'");
    }

    # derive max_doc, relative start offsets
    my $max_doc = 0;
    my @starts;
    for my $searchable ( @{ $self->{searchables} } ) {
        push @starts, $max_doc;
        $max_doc += $searchable->max_doc;
    }
    $self->{max_doc} = $max_doc;
    $self->{starts}  = \@starts;
}

sub max_doc { shift->{max_doc} }

sub close { }

sub _subsearcher {
    my ( $self, $doc_num ) = @_;
    my $i = -1;
    for ( @{ $self->{starts} } ) {
        last if $_ > $doc_num;
        $i++;
    }
    return $i;
}

sub doc_freq {
    my ( $self, $term ) = @_;
    my $doc_freq = 0;
    $doc_freq += $_->doc_freq($term) for @{ $self->{searchables} };
    return $doc_freq;
}

sub fetch_doc {
    my ( $self, $doc_num ) = @_;
    my $i          = $self->_subsearcher($doc_num);
    my $searchable = $self->{searchables}[$i];
    $doc_num -= $self->{starts}[$i];
    return $searchable->fetch_doc($doc_num);
}

sub fetch_doc_vec {
    my ( $self, $doc_num ) = @_;
    my $i          = $self->_subsearcher($doc_num);
    my $searchable = $self->{searchables}[$i];
    $doc_num -= $self->{starts}[$i];
    return $searchable->fetch_doc($doc_num);
}

sub top_docs {
    my $self = shift;
    my ( $searchables, $starts ) = @{$self}{qw( searchables starts )};
    my $top_docs_args = \%KinoSearch::Search::Searchable::top_docs_args;
    confess kerror() unless verify_args( $top_docs_args, @_ );
    my %args = ( %$top_docs_args, @_ );

    # don't allow sort_spec until we fix the sort cache problem.
    confess("sort_spec not currently supported by MultiSearcher")
        if defined $args{sort_spec};

    my $weight = $self->create_weight( $args{query} );

    my $hit_q
        = KinoSearch::Search::HitQueue->new( max_size => $args{num_wanted} );

    my $total_hits = 0;
    for my $i ( 0 .. $#$searchables ) {
        my $searchable = $searchables->[$i];
        my $base       = $starts->[$i];
        my $top_docs   = $searchable->top_docs(%args);
        $total_hits += $top_docs->get_total_hits;
        my $score_docs = $top_docs->get_score_docs;
        for my $score_doc (@$score_docs) {
            $score_doc->set_doc_num( $score_doc->get_doc_num + $base );
            last unless $hit_q->insert_score_doc($score_doc);
        }
    }
    my $score_docs = $hit_q->score_docs;

    my $max_score =
          @$score_docs
        ? $score_docs->[0]->get_score
        : 0;

    return KinoSearch::Search::TopDocs->new(
        score_docs => $score_docs,
        max_score  => $max_score,
        total_hits => $total_hits,
    );
}

sub collect {
    my $self         = shift;
    my $collect_args = \%KinoSearch::Search::Searchable::collect_args;
    confess kerror() unless verify_args( $collect_args, @_ );
    my %args = ( %$collect_args, @_ );
    my ( $searchables, $starts ) = @{$self}{qw( searchables starts )};

    for my $i ( 0 .. $#$searchables ) {
        my $searchable = $searchables->[$i];
        my $start      = $starts->[$i];
        my $collector  = KinoSearch::Search::HitCollector->new_offset_coll(
            collector => $args{collector},
            offset    => $start
        );
        $searchable->collect( %args, collector => $collector );
    }
}

sub create_weight {
    my ( $self, $query ) = @_;
    my $searchables = $self->{searchables};

    # generate an array of unique terms
    my @terms = $query->extract_terms;
    my %unique_terms;
    for my $term (@terms) {
        if ( a_isa_b( $term, "KinoSearch::Index::Term" ) ) {
            $unique_terms{ $term->to_string } = $term;
        }
        else {
            # PhraseQuery returns an array of terms
            $unique_terms{ $_->to_string } = $_ for @$term;
        }
    }
    @terms = values %unique_terms;
    my @stringified = keys %unique_terms;

    # get an aggregated doc_freq for each term
    my @aggregated_doc_freqs = (0) x scalar @terms;
    for my $i ( 0 .. $#$searchables ) {
        my $doc_freqs = $searchables->[$i]->doc_freqs( \@terms );
        for my $j ( 0 .. $#terms ) {
            $aggregated_doc_freqs[$j] += $doc_freqs->[$j];
        }
    }

    # prepare a hashmap of stringified_term => doc_freq pairs.
    my %doc_freq_map;
    @doc_freq_map{@stringified} = @aggregated_doc_freqs;

    my $cache_df_source = KinoSearch::Search::CacheDFSource->new(
        doc_freq_map => \%doc_freq_map,
        max_doc      => $self->max_doc,
        schema       => $self->{schema},
    );

    return $query->make_weight($cache_df_source);
}

package KinoSearch::Search::CacheDFSource;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Searchable );

our %instance_vars = (
    # inherited
    schema => undef,

    # params / members
    doc_freq_map => {},
    max_doc      => undef,
);

sub init_instance { }

sub doc_freq {
    my ( $self, $term ) = @_;
    my $df = $self->{doc_freq_map}{ $term->to_string };
    confess( "df for " . $term->to_string . " not available" )
        unless defined $df;
}

sub doc_freqs {
    my $self = shift;
    my @doc_freqs = map { $self->doc_freq($_) } @_;
    return \@doc_freqs;
}

sub max_doc { shift->{max_doc} }

=for comment

Dummy class, only here to support initialization of Weights from Queries.

=cut

1;

__END__


=head1 NAME

KinoSearch::Search::MultiSearcher - Aggregate results from multiple searchers.

=head1 SYNOPSIS

    my $schema = MySchema->new;
    for my $server_name (@server_names) {
        push @searchers, KinoSearch::Search::SearchClient->new(
            peer_address => "$server_name:$port",
            password     => $pass,
            schema       => $schema,
        );
    }
    my $multi_searcher = KinoSearch::Search::MultiSearcher->new(
        searchables => \@searchers,
        schema      => $schema,
    );
    my $hits = $multi_searcher->search( query => $query );

=head1 DESCRIPTION

Aside from the arguments to its constructor, MultiSearcher looks and acts just
like a L<KinoSearch::Searcher> object, albeit with some limitations.

The primary use for MultiSearcher is to aggregate results from several remote
searchers via L<SearchClient|KinoSearch::Search::SearchClient>, diffusing the
cost of searching a large corpus over multiple machines.

=head2 Limitations

At present, L<SortSpec|KinoSearch::Search::SortSpec> is not supported by
MultiSearcher.  Also, note that L<Filter|KinoSearch::Search::Filter> objects
are not supported by SearchClient.

=head1 METHODS

=head2 new

Constructor.  Takes two hash-style parameters, both of which are required.

=over

=item *

B<schema> - an object which isa L<KinoSearch::Schema>.

=item *

B<searchables> - a reference to an array of searchers.

=back

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
