use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;

use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;
use KinoSearch::Store::LockFactory;

use TestSchema;

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = TestSchema->new;

my $invindex = KinoSearch::InvIndex->clobber(
    schema => TestSchema->new,
    folder => $folder,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

eval {
    my $inv = KinoSearch::InvIndexer->new(
        lock_id  => "somebody_else",
        invindex => $invindex,
    );
};
like( $@, qr/somebody/, "failed to get lock with competing host" );

my $pid = 12345678;
do {
    # fake a write lock
    $folder->delete_file("write.lock");
    my $outstream = $folder->open_outstream('write.lock');
    while ( kill( 0, $pid ) ) {
        $pid++;
    }
    $outstream->print(
        "agent_id: somebody_else\npid: $pid\nlock_name: write\n");
    $outstream->sclose;

    eval {
        my $lock_factory = KinoSearch::Store::LockFactory->new(
            agent_id => 'somebody_else',
            folder   => $invindex->get_folder,
        );
        my $inv = KinoSearch::InvIndexer->new(
            lock_factory => $lock_factory,
            invindex     => $invindex,
        );
    };

    # mitigate (though not eliminate) race condition false failure
} while ( kill( 0, $pid ) );

ok( !$@, "clobbered lock from same host with inactive pid" );
