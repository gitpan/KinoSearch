use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 9;
use List::Util qw( shuffle );

BEGIN { use_ok('KinoSearch::Search::SortSpec') }

package SortSchema::name;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema::speed;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema::weight;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema::home;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema::cat;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema::unused;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package SortSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }
__PACKAGE__->init_fields(qw( name speed weight home cat unused ));

package main;

use KinoSearch::InvIndexer;
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
my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

# first, add vehicles.
$invindexer->add_doc($_) for ( $airplane, $bike, $car );

my @random_strings;
# now add random strings for a second experiment;
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

$invindexer->finish;
my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $results = test_sorted_search( 'vehicle', name => 0 );
is_deeply( $results, [qw( airplane bike car )], "sort by one criteria" );

$results = test_sorted_search( 'vehicle', weight => 0 );
is_deeply( $results, [qw( bike car airplane )], "sort by one criteria" );

$results = test_sorted_search( 'vehicle', name => 1 );
is_deeply( $results, [qw( car bike airplane )], "reverse sort" );

$results = test_sorted_search( 'vehicle', home => 0, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "multiple criteria" );

$results = test_sorted_search( 'vehicle', home => 0, name => 1 );
is_deeply( $results, [qw( airplane car bike )],
    "multiple criteria with reverse" );

$results = test_sorted_search( 'random', name => 0, );
is_deeply( $results, \@random_strings, "random strings" );

$results
    = test_sorted_search( 'bike bike bike car car airplane', unused => 0, );
is_deeply( $results, [qw( bike car airplane )],
    "sorting on field with no values sorts by score" );

# add another seg to invindex, to try out MultiTermList's build_sort_cache 
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

$results = test_sorted_search( 'vehicle', name => 0 );
is_deeply( $results, [qw( airplane bike car )], "Multi-segment sort" );
 
# Take a list of criteria, create a SortSpec, perform a search, and return an
# array of 'name' values for the sorted results.
sub test_sorted_search {
    my $query = shift, my @criteria = @_;

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
        num_wanted => 100,
    );
    my @results;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @results, $hit->{name};
    }

    return \@results;
}
