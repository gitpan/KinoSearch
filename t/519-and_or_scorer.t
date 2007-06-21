
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

use Test::More tests => 75;

use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Search::ANDORScorer;
use KinoSearch::Search::Similarity;
use KinoSearch::Search::TermQuery;
use KinoSearch::Search::TopDocCollector;
use KinoSearch::Search::Tally;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

my $invindex = KinoSearch::InvIndex->clobber(
    folder => KinoSearch::Store::RAMFolder->new,
    schema => MySchema->new,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );

my @docs;

for my $doc_num ( 0 .. 99 ) {
    my $doc = "";
    for my $number ( 1 .. 5 ) {
        $doc .= "$number " if $doc_num % $number == 0;
    }
    push @docs, $doc;
    $invindexer->add_doc( { content => $doc } );
}

$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
my $reader   = $searcher->get_reader;
my $sim      = KinoSearch::Search::Similarity->new;

for my $required ( 1 .. 5 ) {
    for my $optional ( 1 .. 5 ) {
        perform_search( $required, $optional );
    }
}

sub perform_search {
    my ( $required, $optional ) = @_;

    my $and_query = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'content', $required ) );
    my $and_weight = $searcher->create_weight($and_query);
    my $or_query   = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'content', $optional ) );
    my $or_weight     = $searcher->create_weight($or_query);
    my $and_or_scorer = KinoSearch::Search::ANDORScorer->new(
        similarity => $sim,
        and_scorer => $and_weight->scorer($reader),
        or_scorer  => $or_weight->scorer($reader),
    );
    my $collector = KinoSearch::Search::TopDocCollector->new( size => 100 );
    $and_or_scorer->collect( collector => $collector );
    my ( $got_by_score, $got_by_num ) = dig_out_doc_nums($collector);
    my ( $expected_by_count, $expected_by_num )
        = calc_result_sets( $required, $optional );
    is( scalar @$got_by_num,
        scalar @$expected_by_num,
        "total hits: $required $optional"
    );

    is_deeply( $got_by_num, $expected_by_num,
        "got all docs: $required $optional" );

    is_deeply( $got_by_score, $expected_by_count,
        "scores accumulated: $required $optional" );

}

sub calc_result_sets {
    my ( $required, $optional ) = @_;

    my @good;
    my @better;
    for my $doc_num ( 0 .. 99 ) {
        if ( $doc_num % $required == 0 ) {
            if ( $doc_num % $optional == 0 ) {
                push @better, $doc_num;
            }
            else {
                push @good, $doc_num;
            }
        }
    }
    my @by_count_then_num = ( @better, @good );
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
