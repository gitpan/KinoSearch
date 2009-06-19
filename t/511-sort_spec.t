use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 13;
use List::Util qw( shuffle );

package ReverseType;
use base qw( KinoSearch::FieldType::StringType );

sub new {
    return shift->SUPER::new( sortable => 1, @_ );
}

sub compare_values {
    my ( $self, %args ) = @_;
    if ( defined $args{a} ) {
        if   ( defined $args{b} ) { return $args{b} cmp $args{a}; }
        else                      { return 1; }
    }
    elsif ( defined $args{b} ) { return -1; }
    else                       { return 0; }
}

package SortSchema;
use base qw( KinoSearch::Schema );

sub new {
    my $self       = shift->SUPER::new(@_);
    my $unsortable = KinoSearch::FieldType::FullTextType->new(
        analyzer => KinoSearch::Analysis::Tokenizer->new, );
    my $type = KinoSearch::FieldType::StringType->new( sortable => 1 );
    $self->spec_field( name => 'name',   type => $type );
    $self->spec_field( name => 'speed',  type => $type );
    $self->spec_field( name => 'sloth',  type => ReverseType->new );
    $self->spec_field( name => 'weight', type => $type );
    $self->spec_field( name => 'home',   type => $type );
    $self->spec_field( name => 'cat',    type => $type );
    $self->spec_field( name => 'unused', type => $type );
    $self->spec_field( name => 'nope',   type => $unsortable );
    return $self;
}

package main;
use KinoSearch::Test;

my $airplane = {
    name   => 'airplane',
    speed  => '0200',
    sloth  => '0200',
    weight => '8000',
    home   => 'air',
    cat    => 'vehicle',
};
my $bike = {
    name   => 'bike',
    speed  => '0015',
    sloth  => '0015',
    weight => '0025',
    home   => 'land',
    cat    => 'vehicle',
};
my $car = {
    name   => 'car',
    speed  => '0070',
    sloth  => '0070',
    weight => '3000',
    home   => 'land',
    cat    => 'vehicle',
};

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = SortSchema->new;
my $indexer;

sub refresh_indexer {
    $indexer->commit if $indexer;
    $indexer = KinoSearch::Indexer->new(
        index  => $folder,
        schema => $schema,
    );
}

# First, add vehicles.
refresh_indexer();
$indexer->add_doc($_) for ( $airplane, $bike, $car );

my @random_strings;
# Add random strings for an additional experiment.
my @letters = 'a' .. 'z';
for ( 0 .. 99 ) {
    my $string = "";
    for ( 0 .. int( rand(10) ) ) {
        $string .= $letters[ rand @letters ];
    }
    $indexer->add_doc(
        {   cat  => 'random',
            name => $string,
        }
    );
    push @random_strings, $string;
    refresh_indexer() if $_ % 10 == 0;
}
@random_strings = sort @random_strings;

# Add numbers to verify consistent ordering.
for ( shuffle( 0 .. 99 ) ) {
    $indexer->add_doc(
        {   cat  => 'num',
            name => sprintf( '%02d', $_ ),
        }
    );
    refresh_indexer() if $_ % 10 == 0;
}

$indexer->commit;
my $searcher = KinoSearch::Searcher->new( index => $folder );

my $results = test_sorted_search( 'vehicle', 100, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "sort by one criteria" );

SKIP: {
    skip( "known leaks", 2 ) if $ENV{KINO_VALGRIND};
    eval { $results = test_sorted_search( 'vehicle', 100, nope => 0 ) };
    like( $@, qr/sortable/,
        "sorting on a non-sortable field throws an error" );

    eval { $results = test_sorted_search( 'vehicle', 100, unknown => 0 ) };
    like( $@, qr/sortable/, "sorting on an unknown field throws an error" );
}

$results = test_sorted_search( 'vehicle', 100, weight => 0 );
is_deeply( $results, [qw( bike car airplane )], "sort by one criteria" );

$results = test_sorted_search( 'vehicle', 100, name => 1 );
is_deeply( $results, [qw( car bike airplane )], "reverse sort" );

$results = test_sorted_search( 'vehicle', 100, home => 0, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "multiple criteria" );

$results = test_sorted_search( 'vehicle', 100, home => 0, name => 1 );
is_deeply( $results, [qw( airplane car bike )],
    "multiple criteria with reverse" );

$results = test_sorted_search( 'vehicle', 100, speed => 1 );
my $reversed = test_sorted_search( 'vehicle', 100, sloth => 0 );
is_deeply( $results, $reversed, "FieldType_Compare_Values" );

$results = test_sorted_search( 'random', 100, name => 0, );
is_deeply( $results, \@random_strings, "random strings" );

$results
    = test_sorted_search( 'bike bike bike car car airplane', 100, unused => 0,
    );
is_deeply( $results, [qw( airplane bike car )],
    "sorting on field with no values sorts by doc id" );

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

# Add another seg to index.
undef $indexer;
$indexer = KinoSearch::Indexer->new(
    schema => $schema,
    index  => $folder,
);
$indexer->add_doc(
    {   name   => 'carrot',
        speed  => '0000',
        weight => '0001',
        home   => 'land',
        cat    => 'food',
    }
);
$indexer->commit;
$searcher = KinoSearch::Searcher->new( index => $folder );

$results = test_sorted_search( 'vehicle', 100, name => 0 );
is_deeply( $results, [qw( airplane bike car )], "Multi-segment sort" );

# Take a list of criteria, create a SortSpec, perform a search, and return an
# Array of 'name' values for the sorted results.
sub test_sorted_search {
    my ( $query, $num_wanted, @criteria ) = @_;
    my @rules;

    while (@criteria) {
        my $field = shift @criteria;
        my $rev   = shift @criteria;
        push @rules,
            KinoSearch::Search::SortRule->new(
            field   => $field,
            reverse => $rev,
            );
    }
    push @rules, KinoSearch::Search::SortRule->new( type => 'doc_id' );
    my $sort_spec = KinoSearch::Search::SortSpec->new( rules => \@rules );
    my $hits = $searcher->hits(
        query      => $query,
        sort_spec  => $sort_spec,
        num_wanted => $num_wanted,
    );
    my @results;
    while ( my $hit = $hits->next ) {
        push @results, $hit->{name};
    }

    return \@results;
}
