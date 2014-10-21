use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 63;
use List::Util qw( shuffle );
use Storable qw( nfreeze thaw );
use KinoSearch::Test;

package RangeSchema;
use base qw( KinoSearch::Plan::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $self = shift->SUPER::new(@_);
    my $type = KinoSearch::Plan::StringType->new( sortable => 1 );
    $self->spec_field( name => 'name',   type => $type );
    $self->spec_field( name => 'cat',    type => $type );
    $self->spec_field( name => 'unused', type => $type );
    return $self;
}

package main;

my $folder  = KinoSearch::Store::RAMFolder->new;
my $schema  = RangeSchema->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);

my @letters = 'f' .. 't';
my %letters;
my $count = 0;
for my $letter ( shuffle @letters ) {
    $indexer->add_doc(
        {   name => $letter,
            cat  => 'letter',
        }
    );
    $letters{$letter} = ++$count;
}
$indexer->commit;

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $results = test_range_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 1,
    include_lower => 1,
    string        => 'name:[h TO m]',
);
test_results( $results, [ 'h' .. 'm' ], "include lower and upper" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_lower => 1,
);
test_results(
    $results,
    [ 'h' .. 'm' ],
    "include lower and upper (upper not defined)"
);

$results = test_range_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 1,
);
test_results(
    $results,
    [ 'h' .. 'm' ],
    "include lower and upper (lower not defined)"
);

$results = test_range_search(
    field      => 'name',
    lower_term => 'h',
    upper_term => 'm',
);
test_results(
    $results,
    [ 'h' .. 'm' ],
    "include lower and upper (neither defined)"
);

$results = test_range_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 0,
    include_lower => 1,
    string        => 'name:[h TO m}',
);
test_results( $results, [ 'h' .. 'l' ], "include lower but not upper" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 1,
    include_lower => 0,
    string        => 'name:{h TO m]',
);
test_results( $results, [ 'i' .. 'm' ], "include upper but not lower" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'm',
    upper_term    => 'h',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [], "no results when bounds exclude set" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'hh',
    upper_term    => 'm',
    include_upper => 1,
    include_lower => 1,
);
test_results(
    $results,
    [ 'i' .. 'm' ],
    "included bounds not present in index"
);

$results = test_range_search(
    field         => 'name',
    lower_term    => 'hh',
    upper_term    => 'mm',
    include_upper => 0,
    include_lower => 0,
);
test_results(
    $results,
    [ 'i' .. 'm' ],
    "non-included bounds not present in index"
);

$results = test_range_search(
    field         => 'name',
    lower_term    => 'e',
    upper_term    => 'tt',
    include_upper => 1,
    include_lower => 1,
);
test_results(
    $results,
    [ 'f' .. 't' ],
    "included bounds off the end of the lexicon"
);

$results = test_range_search(
    field         => 'name',
    lower_term    => 'e',
    upper_term    => 'tt',
    include_upper => 0,
    include_lower => 0,
);
test_results(
    $results,
    [ 'f' .. 't' ],
    "non-included bounds off the end of the lexicon"
);

$results = test_range_search(
    field         => 'unused',
    lower_term    => 'ff',
    upper_term    => 'tt',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range query on field without values produces empty result set" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'a',
    upper_term    => 'e',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range query expecting no results returns no results" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'a',
    upper_term    => 'e',
    include_upper => 1,
    include_lower => 1,
);
test_results( $results, [],
    "range query expecting no results returns no results" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'u',
    upper_term    => 'z',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range query expecting no results returns no results" );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'u',
    upper_term    => 'z',
    include_upper => 1,
    include_lower => 1,
);
test_results( $results, [],
    "range query expecting no results returns no results" );

$results = test_range_search(
    field      => 'name',
    upper_term => 'm',
    string     => 'name:[* TO m]',
);
test_results( $results, [ 'f' .. 'm' ], "lower term unspecified" );

$results = test_range_search(
    field      => 'name',
    lower_term => 'h',
    string     => 'name:[h TO *]',
);
test_results( $results, [ 'h' .. 't' ], "upper term unspecified" );

eval { $results = test_range_search( field => 'name' ); };
like( $@, qr/lower_term/,
    "Failing to supply either lower_term or upper_term throws an exception" );

# Add more docs, test multi-segment searches.
$indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->add_doc(
    {   name => 'mh',
        cat  => 'letter',
    }
);
$indexer->commit;
$letters{'mh'} = ++$count;
$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

$results = test_range_search(
    field         => 'name',
    lower_term    => 'hh',
    upper_term    => 'mm',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [ 'i' .. 'm', 'mh' ], "multi-segment range query" );

# Take a list of args, create a RangeQuery using them, perform a search, and
# return an array of 'name' values for the sorted results.
sub test_range_search {
    my %args   = @_;
    my $string = delete $args{string};
    my $query  = KinoSearch::Search::RangeQuery->new(%args);
    if ( defined $string ) {
        is( $query->to_string, $string );
    }
    my $frozen = nfreeze($query);
    my $thawed = thaw($frozen);
    ok( $query->equals($thawed), 'equals' );

    my $compiler = $query->make_compiler( searcher => $searcher );
    $frozen = nfreeze($compiler);
    $thawed = thaw($frozen);
    ok( $compiler->equals($thawed), "freeze/thaw compiler" );

    my $hits = $searcher->hits(
        query      => $query,
        num_wanted => 100,
    );
    my @results;
    while ( my $hit = $hits->next ) {
        push @results, $hit->{name};
    }

    return \@results;
}

sub test_results {
    my ( $results, $expected, $note ) = @_;
    @$results = sort @$results;
    is_deeply( $results, $expected, $note );
}
