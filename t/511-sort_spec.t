use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 10;
use List::Util qw( shuffle );

package SortSchema::UnAnalyzed;
use base qw( KinoSearch::FieldSpec::text );
sub analyzed {0}

package SortSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

our %fields = (
    name   => 'SortSchema::UnAnalyzed',
    speed  => 'SortSchema::UnAnalyzed',
    weight => 'SortSchema::UnAnalyzed',
    home   => 'SortSchema::UnAnalyzed',
    cat    => 'SortSchema::UnAnalyzed',
    unused => 'SortSchema::UnAnalyzed',
);

package main;

use KinoSearch::Search::SortSpec;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;

my $airplane = {
    name   => 'airplane',
    speed  => '0200',
    weight => '8000',
    home   => 'air',
    cat    => 'vehicle',
};
my $bike = {
    name   => 'bike',
    speed  => '0015',
    weight => '0025',
    home   => 'land',
    cat    => 'vehicle',
};
my $car = {
    name   => 'car',
    speed  => '0070',
    weight => '3000',
    home   => 'land',
    cat    => 'vehicle',
};

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = SortSchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

# first, add vehicles.
$invindexer->add_doc($_) for ( $airplane, $bike, $car );

my @random_strings;
# add random strings for an additional experiment
my @letters = 'a' .. 'z';
for ( 0 .. 99 ) {
    my $string = "";
    for ( 0 .. int( rand(10) ) ) {
        $string .= $letters[ rand @letters ];
    }
    $invindexer->add_doc(
        {   cat  => 'random',
            name => $string,
        }
    );
    push @random_strings, $string;
}
@random_strings = sort @random_strings;

# add numbers to verify consistent ordering
for ( 0 .. 99 ) {
    $invindexer->add_doc(
        {   cat  => 'num',
            name => sprintf( '%02d', $_ ),
        }
    );
}

$invindexer->finish;
my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $results = test_sorted_search( 'vehicle', 100, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "sort by one criteria" );

$results = test_sorted_search( 'vehicle', 100, weight => 0 );
is_deeply( $results, [qw( bike car airplane )], "sort by one criteria" );

$results = test_sorted_search( 'vehicle', 100, name => 1 );
is_deeply( $results, [qw( car bike airplane )], "reverse sort" );

$results = test_sorted_search( 'vehicle', 100, home => 0, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "multiple criteria" );

$results = test_sorted_search( 'vehicle', 100, home => 0, name => 1 );
is_deeply( $results, [qw( airplane car bike )],
    "multiple criteria with reverse" );

$results = test_sorted_search( 'random', 100, name => 0, );
is_deeply( $results, \@random_strings, "random strings" );

$results
    = test_sorted_search( 'bike bike bike car car airplane', 100, unused => 0,
    );
is_deeply( $results, [qw( bike car airplane )],
    "sorting on field with no values sorts by score" );

my $ten_results    = test_sorted_search( 'num', 10, name => 0 );
my $thirty_results = test_sorted_search( 'num', 30, name => 0 );
my @first_ten_of_thirty = @{$thirty_results}[ 0 .. 9 ];
is_deeply( $ten_results, \@first_ten_of_thirty,
    "same order regardless of queue size" );

$ten_results    = test_sorted_search( 'num', 10, name => 1 );
$thirty_results = test_sorted_search( 'num', 30, name => 1 );
@first_ten_of_thirty = @{$thirty_results}[ 0 .. 9 ];
is_deeply( $ten_results, \@first_ten_of_thirty,
    "same order regardless of queue size (reverse sort)" );

# add another seg to invindex, to try out MultiLexicon's build_sort_cache
undef $invindexer;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->add_doc(
    {   name   => 'carrot',
        speed  => '0000',
        weight => '0001',
        home   => 'land',
        cat    => 'food',
    }
);
$invindexer->finish;
$searcher = KinoSearch::Searcher->new( invindex => $invindex, );

$results = test_sorted_search( 'vehicle', 100, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "Multi-segment sort" );

# Take a list of criteria, create a SortSpec, perform a search, and return an
# array of 'name' values for the sorted results.
sub test_sorted_search {
    my ( $query, $num_wanted, @criteria ) = @_;

    my $sort_spec = KinoSearch::Search::SortSpec->new;
    while (@criteria) {
        my $field_name = shift @criteria;
        my $rev        = shift @criteria;
        $sort_spec->add(
            field   => $field_name,
            reverse => $rev,
        );
    }
    my $hits = $searcher->search(
        query      => $query,
        sort_spec  => $sort_spec,
        num_wanted => $num_wanted,
    );
    my @results;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @results, $hit->{name};
    }

    return \@results;
}
