use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 5;
use KinoSearch::Test;

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = KinoSearch::Test::TestSchema->new;

my $indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
);

$indexer->add_doc( { content => 'foo' } );
undef $indexer;

$indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->add_doc( { content => 'foo' } );
pass("Indexer ignores garbage from interrupted session");
$indexer->optimize;
pass("optimize works as a back-compat synonym for optimize");

SKIP: {
    skip( "Known leak, though might be fixable", 2 ) if $ENV{KINO_VALGRIND};
    eval {
        my $manager
            = KinoSearch::Index::IndexManager->new(
            hostname => 'somebody_else' );
        my $inv = KinoSearch::Indexer->new(
            manager => $manager,
            index   => $folder,
            schema  => $schema,
        );
    };
    like( $@, qr/write.lock/, "failed to get lock with competing host" );
    isa_ok( $@, "KinoSearch::Store::LockErr", "Indexer throws a LockErr" );
}

my $pid = 12345678;
do {
    # Fake a write lock.
    $folder->delete("write.lock") or die "Couldn't delete 'write.lock'";
    my $outstream = $folder->open_out('write.lock')
        or die "Can't open write.lock";
    while ( kill( 0, $pid ) ) {
        $pid++;
    }
    $outstream->print(
        qq|
        {  
            "hostname": "somebody_else",
            "pid": $pid,
            "name": "write"
        }|
    );
    $outstream->close;

    eval {
        my $manager
            = KinoSearch::Index::IndexManager->new(
            hostname => 'somebody_else' );
        my $inv = KinoSearch::Indexer->new(
            manager => $manager,
            schema  => $schema,
            index   => $folder,
        );
    };

    # Mitigate (though not eliminate) race condition false failure.
} while ( kill( 0, $pid ) );

ok( !$@, "clobbered lock from same host with inactive pid" );
