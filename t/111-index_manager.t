use strict;
use warnings;

package NonMergingIndexManager;
use base qw( KinoSearch::Index::IndexManager );
sub recycle { [] }

package BogusManager;
use base qw( KinoSearch::Index::IndexManager );

# Adds a bogus dupe.
sub recycle {
    my $recyclables = shift->SUPER::recycle(@_);
    if (@$recyclables) { push @$recyclables, $recyclables->[0] }
    return $recyclables;
}

package main;

use Test::More tests => 16;
use KinoSearch::Test;

my $folder = KinoSearch::Store::RAMFolder->new;

my $lock_factory = KinoSearch::Store::LockFactory->new(
    folder => $folder,
    host   => 'me',
);

my $lock = $lock_factory->make_lock(
    name    => 'angie',
    timeout => 1000,
);
isa_ok( $lock, 'KinoSearch::Store::Lock', "make_lock" );
is( $lock->get_name, "angie", "correct lock name" );
is( $lock->get_host, "me",    "correct host" );

$lock = $lock_factory->make_shared_lock(
    name    => 'fred',
    timeout => 0,
);
is( ref($lock),      'KinoSearch::Store::SharedLock', "make_shared_lock" );
is( $lock->get_name, "fred",                          "correct lock name" );
is( $lock->get_host, "me",                            "correct host" );

my $schema = KinoSearch::Test::TestSchema->new;
$folder = KinoSearch::Store::RAMFolder->new;

for ( 1 .. 20 ) {
    my $indexer = KinoSearch::Index::Indexer->new(
        schema  => $schema,
        index   => $folder,
        manager => NonMergingIndexManager->new,
    );

    # Two big segs that shouldn't merge, then small, mergable segs.
    my $reps = $_ <= 2 ? 100 : 1;
    $indexer->add_doc( { content => $_ } ) for 1 .. $reps;
    $indexer->commit;
}
my $num_segs = grep {m/segmeta.json/} @{ $folder->list_r };
is( $num_segs, 20, "no merging" );

my $manager = KinoSearch::Index::IndexManager->new;
$manager->set_folder($folder);

my $polyreader = KinoSearch::Index::PolyReader->open( index => $folder );
my $segment = KinoSearch::Index::Segment->new( number => 22 );
my $snapshot
    = KinoSearch::Index::Snapshot->new->read_file( folder => $folder );
my $deletions_writer = KinoSearch::Index::DefaultDeletionsWriter->new(
    schema     => $schema,
    segment    => $segment,
    snapshot   => $snapshot,
    polyreader => $polyreader,
);
my $seg_readers = $manager->recycle(
    reader     => $polyreader,
    cutoff     => 19,
    del_writer => $deletions_writer,
);
is( scalar @$seg_readers, 1, "cutoff" );

$seg_readers = $manager->recycle(
    reader     => $polyreader,
    cutoff     => 0,
    del_writer => $deletions_writer,
);
is( scalar @$seg_readers,
    18, "recycle lots of small segs but leave big ones alone" );

$manager->set_write_lock_timeout(1);
is( $manager->get_write_lock_timeout, 1, "set/get write lock timeout" );
$manager->set_write_lock_interval(2);
is( $manager->get_write_lock_interval, 2, "set/get write lock interval" );
$manager->set_merge_lock_timeout(3);
is( $manager->get_merge_lock_timeout, 3, "set/get merge lock timeout" );
$manager->set_merge_lock_interval(4);
is( $manager->get_merge_lock_interval, 4, "set/get merge lock interval" );
$manager->set_deletion_lock_timeout(5);
is( $manager->get_deletion_lock_timeout, 5, "set/get deletion lock timeout" );
$manager->set_deletion_lock_interval(6);
is( $manager->get_deletion_lock_interval,
    6, "set/get deletion lock interval" );

SKIP: {
    skip( "Known leak", 1 ) if $ENV{KINO_VALGRIND};
    my $indexer = KinoSearch::Index::Indexer->new(
        index   => $folder,
        manager => BogusManager->new,
    );
    eval { $indexer->commit };
    like( $@, qr/recycle/i, "duplicated segment via recycle triggers error" );
}
