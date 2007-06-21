use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 13;
use File::Spec::Functions qw( catfile );

use KinoSearch::Index::DelDocs;

use KinoTestUtils qw( create_invindex );
use TestSchema;

use KinoSearch::Index::SegInfo;
use KinoSearch::Index::SegInfos;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;

my $invindex  = create_invindex( 'a' .. 'e' );
my $folder    = $invindex->get_folder;
my $schema    = $invindex->get_schema;
my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos( folder => $folder );
my $seg_info = $seg_infos->get_info('_1');

my $deldocs = KinoSearch::Index::DelDocs->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

$deldocs->set(3);
$deldocs->set(3);

my @deleted_or_not = map { $deldocs->get($_) } 0 .. 4;
is_deeply( \@deleted_or_not, [ 0, 0, 0, 1, 0 ], "set works" );
is( $deldocs->get_num_deletions, 1, "set increments num_deletions, once" );

my $doc_map = $deldocs->generate_doc_map(0);
my @correct = ( 0, 1, 2, undef, 3 );
my @got;
push @got, $doc_map->get($_) for 0 .. 4;
is_deeply( \@got, \@correct, "doc map maps around deleted docs" );
$doc_map = $deldocs->generate_doc_map(100);
is( $doc_map->get(4), 103,   "doc map handles offset correctly" );
is( $doc_map->get(3), undef, "doc_map handled deletions correctly" );
is( $doc_map->get(6), undef, "doc_map returns undef for out of range" );

$deldocs->clear(3);
$deldocs->clear(3);
$deldocs->clear(3);
is( $deldocs->get_num_deletions, 0, "clear decrements num_deletions, once" );

$deldocs->set(2);
$deldocs->set(1);
$deldocs->write_deldocs;

$deldocs = KinoSearch::Index::DelDocs->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

@deleted_or_not = map { $deldocs->get($_) } 0 .. 7;
is_deeply(
    \@deleted_or_not,
    [ 0, 1, 1, 0, 0, 0, 0, 0 ],
    "write_deldocs and read_deldocs save/recover deletions correctly"
);

is( $deldocs->get_num_deletions, 2,
    "write_deldocs and read_deldocs save/recover num_deletions correctly" );
is( $deldocs->get_cap, 8, "write_deldocs wrote correct number of bytes" );

$folder   = KinoSearch::Store::RAMFolder->new;
$schema   = TestSchema->new;
$invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { content => $_ } ) for 'a' .. 'c';
$invindexer->finish;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->delete_by_term( content => $_ ) for 'a' .. 'c';
$invindexer->finish;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { content => $_ } ) for 'a' .. 'c';
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );
my $hits     = $searcher->search( query            => 'a' );
is( $hits->total_hits, 1, "deleting then re-adding works" );

my @expected;
for ( 'a' .. 'e' ) {
    $hits = $searcher->search( query => $_ );
    my @contents;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @contents, $hit->{content};
    }
    push @expected, \@contents;
}
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->finish( optimize => 1 );
$searcher = KinoSearch::Searcher->new( invindex => $invindex );
@got = ();
for ( 'a' .. 'e' ) {
    $hits = $searcher->search( query => $_ );
    my @contents;
    while ( my $hit = $hits->fetch_hit_hashref ) {
        push @contents, $hit->{content};
    }
    push @got, \@contents;
}
is_deeply( \@got, \@expected, "segment merging handles deletions correctly" );

$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->delete_by_term( content => $_ ) for 'a' .. 'c';
$invindexer->finish;
$searcher = KinoSearch::Searcher->new( invindex => $invindex );
$hits     = $searcher->search( query            => 'a' );
is( $hits->total_hits, 0, "adding and searching empty segments is ok" );

