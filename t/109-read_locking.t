use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 15;

use KinoSearch::Index::IndexReader;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::LockFactory;

use TestSchema;
use KinoTestUtils qw( create_invindex );

sub small_timeout {1}
local *KinoSearch::Index::IndexReader::COMMIT_LOCK_TIMEOUT = *small_timeout;
local *KinoSearch::InvIndexer::COMMIT_LOCK_TIMEOUT         = *small_timeout;

my $invindex = create_invindex(qw( a b c ));
my $folder   = $invindex->get_folder;
my $schema   = $invindex->get_schema;

# artificially create commit lock
$folder->open_outstream('commit.lock');

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { content => 'x' } );
{
    my $captured;
    local $SIG{__WARN__} = sub { $captured = shift; };
    $invindexer->finish( optimize => 1 );
    like( $captured, qr/obsolete/,
        "InvIndexer warns if it can't get a commit lock" );
}

ok( $folder->file_exists('commit.lock'),
    "InvIndexer doesn't delete commit lock when it can't get it" );
my $num_cf_files = grep {m/\.cf$/} $folder->list;
cmp_ok( $num_cf_files, '>', 1,
    "InvIndex doesn't process deletions when it can't get commit lock" );

my $lock_factory = KinoSearch::Store::LockFactory->new(
    agent_id => 'me',
    folder   => $invindex->get_folder,
);
my $reader;
eval {
    $reader = KinoSearch::Index::IndexReader->open(
        invindex     => $invindex,
        lock_factory => $lock_factory,
    );
};
like( $@, qr/commit/, "IndexReader dies if it can't get commit lock" );
$folder->delete_file('commit.lock');

Test_race_condition_1: {
    my $latest_segs_file = $folder->latest_gen( 'segments', 'yaml' );
    $folder->rename_file( $latest_segs_file, 'temp' );
    my $num_passes = 0;
    local $KinoSearch::Index::IndexReader::debug1 = sub {
        my $self = shift;
        $folder->rename_file( 'temp', $latest_segs_file )
            if $folder->file_exists('temp');
        $num_passes++;
    };
    $reader = KinoSearch::Index::IndexReader->open(
        invindex     => $invindex,
        lock_factory => $lock_factory,
    );
    is( $reader->num_docs, 4,
              "reader overcomes race condition of "
            . "new segs file appearing after read lock" );
    is( $num_passes, 2, "reader retried before succeeding" );

    $reader->close;
}

{
    # force no merging of segs
    sub zilch { }
    local *KinoSearch::Index::MultiReader::segreaders_to_merge = *zilch;

    # collapse to one segment
    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    $invindexer->finish( optimize => 1 );
    my $num_segs_files = scalar grep {m/segments_\w+\.yaml$/} $folder->list;
    is( $num_segs_files, 1, "collapse to one seg" );

    # add a second segment and delete one doc from existing segment
    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    $invindexer->add_doc( { content => 'foo' } );
    $invindexer->add_doc( { content => 'bar' } );
    $invindexer->delete_by_term( content => 'x' );
    $invindexer->finish;

    # delete a doc from the second seg and increase del gen on first seg
    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    $invindexer->delete_by_term( content => 'a' );
    $invindexer->delete_by_term( content => 'foo' );
    $invindexer->finish;
}

# establish read lock
$reader = KinoSearch::Index::IndexReader->open(
    invindex     => $invindex,
    lock_factory => $lock_factory,
);

$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->delete_by_term( content => 'a' );
$invindexer->finish( optimize => 1 );

my @files = $folder->list;
my $num_segs_files = scalar grep {m/segments_\w+\.yaml$/} @files;
is( $num_segs_files, 2, "lock preserved last segments file" );
my $num_del_files = scalar grep {m/\.del$/} @files;
is( $num_del_files, 2, "outdated but locked del files survive" );
ok( $folder->file_exists('_3_3.del'), "first correct old del file" );
ok( $folder->file_exists('_4_2.del'), "second correct old del file" );
$num_cf_files = scalar grep {m/\.cf$/} @files;
cmp_ok( $num_cf_files, '>', 1, "compound files preserved" );

undef $reader;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->finish( optimize => 1 );

@files = $folder->list;
$num_del_files = scalar grep {m/\.del$/} @files;
is( $num_del_files, 0, "lock freed, del files optimized away" );
$num_segs_files = scalar grep {m/segments_\w+\.yaml$/} @files;
is( $num_segs_files, 1, "lock freed, now only one segments file" );
$num_cf_files = scalar grep {m/\.cf$/} @files;
is( $num_cf_files, 1, "lock freed, now only one cf file" );
