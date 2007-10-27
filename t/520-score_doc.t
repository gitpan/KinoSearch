use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;

BEGIN {
    use_ok('KinoSearch::Search::ScoreDoc');
    use_ok('KinoSearch::Search::FieldDoc');
}

use KinoSearch::Search::FieldDocCollator;
use KinoSearch::Util::IntMap;
use Storable qw( freeze thaw );

my $score_doc = KinoSearch::Search::ScoreDoc->new(
    doc_num => 31,
    score   => 5.0,
);
is( $score_doc->get_doc_num, 31,  "get_doc_num" );
is( $score_doc->get_score,   5.0, "get_score" );
my $score_doc_copy = thaw( freeze($score_doc) );
is( $score_doc_copy->get_doc_num,
    $score_doc->get_doc_num, "doc_num survives serialization" );
is( $score_doc_copy->get_score, $score_doc->get_score,
    "score survives serialization" );

my $map = KinoSearch::Util::IntMap->new( ints => pack( 'III', 1, 0, 20 ) );
my $collator
    = KinoSearch::Search::FieldDocCollator->new( sort_cache => $map );

my $field_doc = KinoSearch::Search::FieldDoc->new(
    doc_num  => 1,
    score    => 6,
    collator => $collator,
);
is( $field_doc->get_doc_num => 1, "FieldDoc get_doc_num" );

