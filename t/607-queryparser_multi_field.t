use strict;
use warnings;
use lib 'buildlib';

package UnAnalyzed;
use base qw( KinoSearch::FieldSpec::text );

sub analyzed {0}

package MultiFieldSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    a => 'text',
    b => 'text',
    c => 'UnAnalyzed',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 11;

use KinoSearch::QueryParser;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;

use KinoTestUtils qw( create_invindex );

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MultiFieldSchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { a => 'foo' } );
$invindexer->add_doc( { b => 'foo' } );
$invindexer->add_doc( { a => 'United States unit state' } );
$invindexer->add_doc( { a => 'unit state' } );
$invindexer->add_doc( { c => 'unit' } );
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $hits = $searcher->search( query => 'foo' );
is( $hits->total_hits, 2, "Searcher's default is to find all fields" );

my $qparser = KinoSearch::QueryParser->new( schema => $schema );
my $query = $qparser->parse('foo');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 2, "QueryParser's default is to find all fields" );

$query = $qparser->parse('b:foo');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 0, "no set_heed_colons" );

$qparser->set_heed_colons(1);
$query = $qparser->parse('b:foo');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 1, "set_heed_colons" );

$query = $qparser->parse('a:boffo.moffo');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 0,
    "no crash for non-existent phrases under heed_colons" );

$query = $qparser->parse('a:x.nope');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 0,
    "no crash for non-existent terms under heed_colons" );

$query = $qparser->parse('nyet:x.x');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 0,
    "no crash for non-existent fields under heed_colons" );

$qparser = KinoSearch::QueryParser->new(
    schema => $schema,
    fields => ['a'],
);
$query = $qparser->parse('foo');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 1, "QueryParser fields param works" );

my $analyzer_parser = KinoSearch::QueryParser->new(
    schema   => $schema,
    analyzer => KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' ),
);

$hits = $searcher->search( query => 'United States' );
is( $hits->total_hits, 1, "search finds 1 doc (prep for next text)" );

$query = $analyzer_parser->parse('unit');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 3, "QueryParser uses supplied Analyzer" );

$query = $analyzer_parser->parse('United States');
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 2, "QueryParser doesn't analyze non-analyzed fields" );


