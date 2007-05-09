use strict;
use warnings;
use lib 'buildlib';

package FlatSim;
use base qw( KinoSearch::Search::Similarity );

# Force no length normalization and no idf, so that score is directly
# proportional to number of terms matched.
sub length_norm {1}
sub idf         {1}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'KinoSearch::Schema::FieldSpec' );

sub similarity { FlatSim->new }
sub analyzer   { KinoSearch::Analysis::Tokenizer->new }

package main;

use Test::More tests => 81;

use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Search::ORScorer;
use KinoSearch::Search::Similarity;
use KinoSearch::Search::TermQuery;
use KinoSearch::Search::TopDocCollector;
use KinoSearch::Search::Tally;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

my @docs;
my %letters;

for my $letter ( 'a' .. 'z' ) {
    my %doc_nums;
    # put each letter in 20 docs
    for ( 1 .. 10 ) {
        my $num = int( rand(20) );
        $doc_nums{$num} = 1;
    }
    $letters{$letter} = \%doc_nums;
}

for my $doc_num ( 0 .. 20 ) {
    my $doc = "";
    for my $letter ( 'a' .. 'z' ) {
        $doc .= "$letter " if $letters{$letter}{$doc_num};
    }
    push @docs, $doc;
}

my $invindex = KinoSearch::InvIndex->create(
    folder => KinoSearch::Store::RAMFolder->new,
    schema => MySchema->new,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { content => $_ } ) for @docs;
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
my $reader   = $searcher->get_reader;
my $sim      = KinoSearch::Search::Similarity->new;

=begin comment 

These tests exercise many facets of ORScorer at once.

   * 0, 1, 2, and many internal scorers to cover edge cases.
   * Randomness of doc content ensures that the ScorerDocQueue will contort
     itself into many possible states.
   * Scores from multiple subscorers get properly accumulated.

=end comment
=cut 

perform_search( [] );
perform_search( [ 'a' .. $_ ] ) for 'a' .. 'z';

sub perform_search {
    my $letters       = shift;
    my $letter_string = join ' ', @$letters;

    my $subscorers
        = KinoSearch::Util::VArray->new( capacity => scalar @$letters );

    for my $letter (@$letters) {
        my $term_query = KinoSearch::Search::TermQuery->new(
            term => KinoSearch::Index::Term->new( 'content', $letter ) );
        my $term_weight = $searcher->create_weight($term_query);
        my $term_scorer = $term_weight->scorer($reader);
        $subscorers->push($term_scorer);
    }
    my $or_scorer = KinoSearch::Search::ORScorer->new(
        similarity => $sim,
        subscorers => $subscorers,
    );
    my $collector = KinoSearch::Search::TopDocCollector->new( size => 100 );
    $or_scorer->collect( collector => $collector );
    my ( $got_by_score, $got_by_num ) = dig_out_doc_nums($collector);
    my ( $expected_by_count, $expected_by_num )
        = union_doc_num_sets($letters);
    is( scalar @$got_by_num,
        scalar @$expected_by_num,
        "total hits: $letter_string"
    );

    is_deeply( $got_by_num, $expected_by_num,
        "got all docs: $letter_string" );

    is_deeply( $got_by_score, $expected_by_count,
        "scores accumulated: $letter_string" );

}

sub union_doc_num_sets {
    my $letters = shift;
    my %counts;
    for my $letter (@$letters) {
        my @doc_nums = keys %{ $letters{$letter} };
        $counts{$_} += 1 for @doc_nums;
    }
    my @by_count_then_num =
        sort { $counts{$b} <=> $counts{$a} || $a <=> $b }
        keys %counts;

    my @by_num = sort { $a <=> $b } @by_count_then_num;
    return ( \@by_count_then_num, \@by_num );
}

sub dig_out_doc_nums {
    my $hc = shift;
    my @by_score;
    my $score_docs = $hc->get_hit_queue->score_docs;
    my @by_score_then_num = map { $_->get_doc_num }
        sort {
        $b->get_score <=> $a->get_score
            || $a->get_doc_num <=> $b->get_doc_num
        } @$score_docs;
    my @by_num = sort { $a <=> $b } @by_score_then_num;
    return ( \@by_score_then_num, \@by_num );
}
