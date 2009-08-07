use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 15;

package FastIndexManager;
use base qw( KinoSearch::Index::IndexManager );

sub new {
    my $self = shift->SUPER::new(@_);
    $self->set_deletion_lock_timeout(100);
    return $self;
}

package NonMergingIndexManager;
use base qw( FastIndexManager );
sub recycle { [] }

package main;

use KinoSearch::Test::TestUtils qw( create_index );
use KinoSearch::Util::IndexFileNames qw( latest_snapshot );

my $folder  = create_index(qw( a b c ));
my $schema  = KinoSearch::Test::TestSchema->new;
my $indexer = KinoSearch::Indexer->new(
    index   => $folder,
    schema  => $schema,
    manager => FastIndexManager->new,
    create  => 1,
);
$indexer->delete_by_term( field => 'content', term => $_ ) for qw( a b c );
$indexer->add_doc( { content => 'x' } );

# Artificially create deletion lock.
my $outstream = $folder->open_out('deletion.lock')
    or die "Can't open deletion.lock";
$outstream->print("{}");
$outstream->close;
{
    my $captured;
    local $SIG{__WARN__} = sub { $captured = shift; };
    $indexer->commit;
    like( $captured, qr/obsolete/,
        "Indexer warns if it can't get a deletion lock" );
}

ok( $folder->exists('deletion.lock'),
    "Indexer doesn't delete deletion lock when it can't get it" );
my $num_ds_files = grep {m/documents\.dat$/} @{ $folder->list };
cmp_ok( $num_ds_files, '>', 1,
    "Indexer doesn't process deletions when it can't get deletion lock" );

my $num_snap_files = grep {m/snapshot/} @{ $folder->list };
is( $num_snap_files, 2, "didn't zap the old snap file" );

my $reader;
SKIP: {
    skip( "IndexReader opening failure leaks", 1 )
        if $ENV{KINO_VALGRIND};
    eval {
        $reader = KinoSearch::Index::IndexReader->open(
            index   => $folder,
            manager => FastIndexManager->new( hostname => 'me' ),
        );
    };
    like( $@, qr/deletion/,
        "IndexReader dies if it can't get deletion lock" );
}
$folder->delete('deletion.lock') or die "Can't delete 'deletion.lock'";

Test_race_condition_1: {
    my $latest_snapshot_file = latest_snapshot($folder);

    # Artificially set up situation where the index was updated and files
    # PolyReader was expecting to see were zapped after a snapshot file was
    # picked.
    $folder->rename( from => $latest_snapshot_file, to => 'temp' );
    $folder->rename( from => $_, to => "$_.hidden" )
        for grep {m#^seg_1/.#} @{ $folder->list };
    KinoSearch::Index::IndexReader::set_race_condition_debug1(
        KinoSearch::Obj::CharBuf->new($latest_snapshot_file) );

    $reader = KinoSearch::Index::IndexReader->open(
        index   => $folder,
        manager => FastIndexManager->new( hostname => 'me' ),
    );
    is( $reader->doc_count, 1,
        "reader overcomes race condition of index update after read lock" );
    is( KinoSearch::Index::IndexReader::debug1_num_passes(),
        2, "reader retried before succeeding" );

    # Clean up our artificial mess.
    for my $entry ( @{ $folder->list } ) {
        next unless $entry =~ m#(.*)\.hidden#;
        $folder->rename( from => $entry, to => $1 );
    }
    KinoSearch::Index::IndexReader::set_race_condition_debug1(undef);

    $reader->close;
}

# Start over with one segment.
$folder = create_index(qw( a b c x ));

{
    # Add a second segment and delete one doc from existing segment.
    $indexer = KinoSearch::Indexer->new(
        schema  => $schema,
        index   => $folder,
        manager => NonMergingIndexManager->new,
    );
    $indexer->add_doc( { content => 'foo' } );
    $indexer->add_doc( { content => 'bar' } );
    $indexer->delete_by_term( field => 'content', term => 'x' );
    $indexer->commit;

    # Delete a doc from the second seg and increase del gen on first seg.
    $indexer = KinoSearch::Indexer->new(
        schema  => $schema,
        index   => $folder,
        manager => NonMergingIndexManager->new,
    );
    $indexer->delete_by_term( field => 'content', term => 'a' );
    $indexer->delete_by_term( field => 'content', term => 'foo' );
    $indexer->commit;
}

# Establish read lock.
$reader = KinoSearch::Index::IndexReader->open(
    index   => $folder,
    manager => FastIndexManager->new( hostname => 'me' ),
);

$indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->delete_by_term( field => 'content', term => 'a' );
$indexer->optimize;
$indexer->commit;

my $files = $folder->list;
$num_snap_files = scalar grep {m/snapshot_\w+\.json$/} @$files;
is( $num_snap_files, 2, "lock preserved last snapshot file" );
my $num_del_files = scalar grep {m/deletions-seg_1\.bv$/} @$files;
is( $num_del_files, 2, "outdated but locked del files survive" );
ok( $folder->exists('seg_3/deletions-seg_1.bv'),
    "first correct old del file" );
ok( $folder->exists('seg_3/deletions-seg_2.bv'),
    "second correct old del file" );
$num_ds_files = scalar grep {m/documents\.dat$/} @$files;
cmp_ok( $num_ds_files, '>', 1, "segment data files preserved" );

undef $reader;
$indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->optimize;
$indexer->commit;

$files = $folder->list;
$num_del_files = scalar grep {m/deletions/} @$files;
is( $num_del_files, 0, "lock freed, del files optimized away" );
$num_snap_files = scalar grep {m/snapshot_\w+\.json$/} @$files;
is( $num_snap_files, 1, "lock freed, now only one snapshot file" );
$num_ds_files = scalar grep {m/documents\.dat$/} @$files;
is( $num_ds_files, 1, "lock freed, now only one ds file" );
