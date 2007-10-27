use strict;
use warnings;
use lib 'buildlib';

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'text' );

sub analyzer { KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/ ) }

package main;
use Test::More tests => 16;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Index::Term;
use KinoSearch::QueryParser;
use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Search::TermQuery;
use KinoTestUtils qw( utf8_test_strings );

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

my $turd = pack( 'C*', 254, 254 );
my $polished_turd = $turd;
utf8::upgrade($polished_turd);

is( $turd, $polished_turd, "verify encoding acrobatics" );

my $invindex = KinoSearch::InvIndex->clobber(
    folder => KinoSearch::Store::RAMFolder->new,
    schema => MySchema->new,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

$invindexer->add_doc( { content => $smiley } );
$invindexer->add_doc( { content => $not_a_smiley } );
$invindexer->add_doc( { content => $turd } );
$invindexer->finish;

my $qparser  = KinoSearch::QueryParser->new( schema => MySchema->new );
my $searcher = KinoSearch::Searcher->new( invindex  => $invindex );

my $hits = $searcher->search( query => $qparser->parse($smiley) );
is( $hits->total_hits, 1 );
is( $hits->fetch_hit_hashref->{content},
    $smiley, "InvIndexer and QueryParser handle UTF-8 source correctly" );

$hits = $searcher->search( query => $qparser->parse($frowny) );
is( $hits->total_hits, 1 );
is( $hits->fetch_hit_hashref->{content},
    $frowny, "InvIndexer upgrades non-UTF-8 correctly" );

$hits = $searcher->search( query => $qparser->parse($not_a_smiley) );
is( $hits->total_hits, 1 );
is( $hits->fetch_hit_hashref->{content},
    $not_a_smiley, "QueryParser upgrades non-UTF-8 correctly" );

my $term = KinoSearch::Index::Term->new( content => $not_a_smiley );
my $upgraded_term_text = $term->get_text;
utf8::upgrade($upgraded_term_text);
is( $upgraded_term_text, $not_a_smiley, "Term upgrades non-UTF-8 correctly" );

my $term_query = KinoSearch::Search::TermQuery->new( term => $term );
$hits = $searcher->search( query => $term_query );
is( $hits->total_hits, 1 );
is( $hits->fetch_hit_hashref->{content},
    $not_a_smiley, "Term upgrades non-UTF-8 correctly" );

$term = KinoSearch::Index::Term->new( content => $smiley );
$upgraded_term_text = $term->get_text;
utf8::upgrade($upgraded_term_text);
is( $upgraded_term_text, $smiley, "Term handles UTF-8 correctly" );

$term_query = KinoSearch::Search::TermQuery->new( term => $term );

$hits = $searcher->search( query => $term_query );
is( $hits->total_hits, 1 );
is( $hits->fetch_hit_hashref->{content},
    $smiley, "Term handles UTF-8 correctly" );

undef $invindexer;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->delete_by_term( content => $smiley );
$invindexer->finish;
$searcher = KinoSearch::Searcher->new( invindex => $invindex );

$hits = $searcher->search( query => $smiley );
is( $hits->total_hits, 0, "delete_by_term handles UTF-8 correctly" );

$hits = $searcher->search( query => $frowny );
is( $hits->total_hits, 1, "delete_by_term handles UTF-8 correctly" );

undef $invindexer;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->delete_by_term( content => $not_a_smiley );
$invindexer->finish;
$searcher = KinoSearch::Searcher->new( invindex => $invindex );

$hits = $searcher->search( query => $frowny );
is( $hits->total_hits, 0, "delete_by_term upgrades non-UTF-8 correctly" );
