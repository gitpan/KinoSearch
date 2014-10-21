use strict;
use warnings;
use lib 'buildlib';

package NoMergeManager;
use base qw( KinoSearch::Index::IndexManager );
sub recycle { [] }

package main;
use Test::More tests => 15;
use KinoSearch::Test;

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = KinoSearch::Test::TestSchema->new;

for my $letter (qw( a b c )) {
    my $indexer = KinoSearch::Index::Indexer->new(
        index   => $folder,
        schema  => $schema,
        manager => NoMergeManager->new,
    );
    $indexer->add_doc( { content => $letter } );
    $indexer->commit;
}
my $bg_merger = KinoSearch::Index::BackgroundMerger->new( index => $folder );

my $indexer = KinoSearch::Index::Indexer->new( index => $folder );
$indexer->add_doc( { content => 'd' } );
$indexer->commit;

is( count_segs($folder), 4,
    "BackgroundMerger prevents Indexer from merging claimed segments" );

$indexer = KinoSearch::Index::Indexer->new( index => $folder );
$indexer->add_doc( { content => 'e' } );
$indexer->delete_by_term( field => 'content', term => 'b' );
$indexer->commit;
is( count_segs($folder), 4, "Indexer may still merge unclaimed segments" );

$bg_merger->commit;
is( count_segs($folder), 3, "Background merge completes" );
ok( $folder->exists("seg_7/deletions-seg_4.bv"),
    "deletions carried forward" );

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
is( $searcher->hits( query => 'b' )->total_hits,
    0, "deleted term still deleted" );
is( $searcher->hits( query => $_ )->total_hits, 1, "term $_ still present" )
    for qw( a c d e );

# Simulate failed background merge.
$bg_merger = KinoSearch::Index::BackgroundMerger->new( index => $folder );
$bg_merger->prepare_commit;
undef $bg_merger;
$folder->delete("merge.lock");
die "test set up failed" unless $folder->exists("merge.json");

$indexer = KinoSearch::Index::Indexer->new( index => $folder );
$indexer->optimize;
$indexer->commit;

ok( !$folder->exists("merge.json"), "Cleaned up after failed bg merge" );

$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
is( $searcher->hits( query => 'b' )->total_hits,
    0, "deleted term still deleted after full optimize" );
is( $searcher->hits( query => $_ )->total_hits,
    1, "term $_ still present after full optimize" )
    for qw( a c d e );

sub count_segs {
    my $folder = shift;
    return scalar grep {m/segmeta\.json/} @{ $folder->list_r };
}
