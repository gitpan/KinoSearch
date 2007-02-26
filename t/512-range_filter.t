use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 9;
use List::Util qw( shuffle );

BEGIN { use_ok('KinoSearch::Search::RangeFilter') }

package RangeSchema::name;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package RangeSchema::cat;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package RangeSchema::unused;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package RangeSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }
__PACKAGE__->init_fields(qw( name cat unused ));

package main;

use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = RangeSchema->new;
my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

my @letters = 'a' .. 'z';
for my $letter ( shuffle @letters ) {
    $invindexer->add_doc(
        {   name => $letter,
            cat  => 'letter',
        }
    );
}
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $results = test_filtered_search(
    field         => 'name',
    lower_term    => 'b',
    upper_term    => 's',
    include_upper => 1,
    include_lower => 1,
);
@$results = sort @$results;
is_deeply( $results, [ 'b' .. 's' ], "include lower and upper" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'b',
    upper_term    => 's',
    include_upper => 0,
    include_lower => 1,
);
@$results = sort @$results;
is_deeply( $results, [ 'b' .. 'r' ], "include lower but not upper" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'b',
    upper_term    => 's',
    include_upper => 1,
    include_lower => 0,
);
@$results = sort @$results;
is_deeply( $results, [ 'c' .. 's' ], "include upper but not lower" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 's',
    upper_term    => 'b',
    include_upper => 0,
    include_lower => 0,
);
@$results = sort @$results;
is_deeply( $results, [], "no results when bounds exclude set" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'bb',
    upper_term    => 's',
    include_upper => 1,
    include_lower => 1,
);
@$results = sort @$results;
is_deeply( $results, [ 'c' .. 's' ], "included bounds not present in index" );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'bb',
    upper_term    => 'ss',
    include_upper => 0,
    include_lower => 0,
);
@$results = sort @$results;
is_deeply(
    $results,
    [ 'c' .. 's' ],
    "non-included bounds not present in index"
);

$results = test_filtered_search(
    field         => 'unused',
    lower_term    => 'bb',
    upper_term    => 'ss',
    include_upper => 0,
    include_lower => 0,
);
@$results = sort @$results;
is_deeply( $results, [],
    "range filter on field without values produces empty result set" );

# Add more docs, test multi-segment searches.
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->add_doc(
    {   name => 'sh',
        cat  => 'letter',
    }
);
$invindexer->finish;
$searcher = KinoSearch::Searcher->new( invindex => $invindex, );

$results = test_filtered_search(
    field         => 'name',
    lower_term    => 'bb',
    upper_term    => 'sm',
    include_upper => 0,
    include_lower => 0,
);
@$results = sort @$results;
is_deeply(
    $results,
    [ 'c' .. 's', 'sh' ],
    "multi-segment rangefiltered search"
);

# Take a list of args, create a RangeFilter using them, perform a search, and
# return an array of 'name' values for the sorted results.
sub test_filtered_search {
    my $filter = KinoSearch::Search::RangeFilter->new(@_);
    my $hits   = $searcher->search(
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

