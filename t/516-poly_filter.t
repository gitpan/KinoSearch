use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 10;
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

use KinoSearch::Search::HitCollector;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;
use KinoSearch::Search::QueryFilter;
use KinoSearch::Search::RangeFilter;
use KinoSearch::Search::PolyFilter;
use KinoSearch::Store::RAMFolder;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = RangeSchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

my @letters = 'a' .. 'z';
@letters = shuffle @letters;
$invindexer->add_doc( { name => $_, cat => 'letter' } ) for @letters;
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $vowels = join ' ', ( my @vowels = qw(a e i o u) );

# single tests
my $poly_filter = KinoSearch::Search::PolyFilter->new;
test_filters( $vowels, [@vowels], 'no filter' );

$poly_filter->add( filter => vowel_filter('a'), logic => 'AND' );
test_filters( $vowels, ['a'], 'AND only' );

$poly_filter = KinoSearch::Search::PolyFilter->new;
$poly_filter->add( filter => vowel_filter('a'), logic => 'OR' );
test_filters( $vowels, ['a'], 'OR only' );

$poly_filter = KinoSearch::Search::PolyFilter->new;
$poly_filter->add( filter => vowel_filter('a'), logic => 'XOR' );
test_filters( $vowels, ['a'], 'XOR only' );

$poly_filter = KinoSearch::Search::PolyFilter->new;
$poly_filter->add( filter => vowel_filter('a'), logic => 'NOT' );
test_filters( $vowels, [qw(e i o u)], 'NOT only' );

# getting a little crazy
$poly_filter = KinoSearch::Search::PolyFilter->new;
for (@vowels) {
    $poly_filter->add( filter => vowel_filter($_), logic => 'OR' );
}

my $range_filter = KinoSearch::Search::RangeFilter->new(
    field         => 'name',
    lower_term    => 'b',
    upper_term    => 's',
    include_upper => 1,
    include_lower => 1,
);

test_filters( $vowels, [@vowels], 'vowels only' );
test_filters( $vowels, [qw(e i o)], 'vowels AND', 'AND' );
test_filters( $vowels, [@vowels],   'vowels OR',  'OR' );
test_filters( $vowels, [qw(a u)],   'vowels XOR', 'XOR' );
test_filters( $vowels, [qw(a u)],   'vowels NOT', 'NOT' );

# Take a list of args, create a PolyFilter using them, perform a search, and
# test that the results match the expected values.
sub test_filters {
    my ( $query, $expected, $note, $logic_op ) = @_;

    my $filter = $poly_filter;
    if ($logic_op) {
        $filter = KinoSearch::Search::PolyFilter->new;
        $filter->add( filter => $poly_filter );
        $filter->add( filter => $range_filter, logic => $logic_op );
    }

    my $hits = $searcher->search(
        query      => $query,
        filter     => $filter,
        num_wanted => 100,
    );

    my @results;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @results, $hit->{name};
    }

    @results = sort @results;
    is_deeply( \@results, $expected, $note );
}

sub vowel_filter {
    my $vowel_filter = KinoSearch::Search::QueryFilter->new(
        query => KinoSearch::Search::TermQuery->new(
            term => KinoSearch::Index::Term->new( 'name', shift )
        )
    );
}
