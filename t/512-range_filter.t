use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 39;
use List::Util qw( shuffle );

package RangeSchema::UnAnalyzed;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package RangeSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    name   => 'RangeSchema::UnAnalyzed',
    cat    => 'RangeSchema::UnAnalyzed',
    unused => 'RangeSchema::UnAnalyzed',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use KinoSearch::Search::RangeFilter;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = RangeSchema->new;
my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

my @letters = 'f' .. 't';
my %letters;
for my $letter ( shuffle @letters ) {
    $invindexer->add_doc(
        {   name => $letter,
            cat  => 'letter',
        }
    );
    $letters{$letter} = scalar keys %letters;
}
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
my $filter;

my $results = test_filtered_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 1,
    include_lower => 1,
);
test_results( $results, [ 'h' .. 'm' ], "include lower and upper" );

$results = test_filtered_search(
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

$results = test_filtered_search(
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

$results = test_filtered_search(
    field      => 'name',
    lower_term => 'h',
    upper_term => 'm',
);
test_results(
    $results,
    [ 'h' .. 'm' ],
    "include lower and upper (neither defined)"
);

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 0,
    include_lower => 1,
);
test_results( $results, [ 'h' .. 'l' ], "include lower but not upper" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'h',
    upper_term    => 'm',
    include_upper => 1,
    include_lower => 0,
);
test_results( $results, [ 'i' .. 'm' ], "include upper but not lower" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'm',
    upper_term    => 'h',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [], "no results when bounds exclude set" );

$results = test_filtered_search(
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

$results = test_filtered_search(
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

$results = test_filtered_search(
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

$results = test_filtered_search(
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

$results = test_filtered_search(
    field         => 'unused',
    lower_term    => 'ff',
    upper_term    => 'tt',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range filter on field without values produces empty result set" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'a',
    upper_term    => 'e',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range filter expecting no results returns no results" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'a',
    upper_term    => 'e',
    include_upper => 1,
    include_lower => 1,
);
test_results( $results, [],
    "range filter expecting no results returns no results" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'u',
    upper_term    => 'z',
    include_upper => 0,
    include_lower => 0,
);
test_results( $results, [],
    "range filter expecting no results returns no results" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'u',
    upper_term    => 'z',
    include_upper => 1,
    include_lower => 1,
);
test_results( $results, [],
    "range filter expecting no results returns no results" );

$results = test_filtered_search(
    field      => 'name',
    upper_term => 'm',
);
test_results( $results, [ 'f' .. 'm' ], "lower term unspecified" );

$results = test_filtered_search(
    field      => 'name',
    lower_term => 'h',
);
test_results( $results, [ 'h' .. 't' ], "upper term unspecified" );

eval { $results = test_filtered_search( field => 'name' ); };
like( $@, qr/lower_term/,
    "Failing to supply either lower_term or upper_term throws an exception" );

# Add more docs, test multi-segment searches.
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->add_doc(
    {   name => 'mh',
        cat  => 'letter',
    }
);
$invindexer->finish;
$letters{'mh'} = scalar keys %letters;
$searcher = KinoSearch::Searcher->new( invindex => $invindex, );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'hh',
    upper_term    => 'mm',
    include_upper => 0,
    include_lower => 0,
);
test_results(
    $results,
    [ 'i' .. 'm', 'mh' ],
    "multi-segment rangefiltered search"
);

# Take a list of args, create a RangeFilter using them, perform a search, and
# return an array of 'name' values for the sorted results.
sub test_filtered_search {
    $filter = KinoSearch::Search::RangeFilter->new(@_);

    my $hits = $searcher->search(
        query      => 'letter',
        filter     => $filter,
        num_wanted => 100,
    );
    my @results;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @results, $hit->{name};
    }

    return \@results;
}

sub test_results {
    my ( $results, $expected, $note ) = @_;
    @$results = sort @$results;
    is_deeply( $results, $expected, $note );

    my @expected = sort { $a <=> $b } grep defined,
        map { $letters{$_} } @$expected;
    my $bits = $filter->bits( $searcher->{reader} )->to_arrayref;
    is_deeply( $bits, \@expected, "$note (bits)" );
}
