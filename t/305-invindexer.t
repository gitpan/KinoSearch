use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 3;

BEGIN { use_ok('KinoSearch::InvIndexer') }

use TestSchema;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = TestSchema->new,

    my $invindex = KinoSearch::InvIndex->create(
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

my $pid = $$;
do {
    # fake a write lock
    $folder->delete_file("write.lock");
    my $outstream = $folder->open_outstream('write.lock');
    while ( kill( 0, $pid ) ) {
        $pid++;
    }
    $outstream->print("lock_id: somebody_else\npid: $pid\n");
    $outstream->sclose;

    eval {
        my $inv = KinoSearch::InvIndexer->new(
            lock_id  => "somebody_else",
            invindex => $invindex,
        );
    };

    # mitigate (though not eliminate) race condition false failure
} while ( kill( 0, $pid ) );

ok( !$@, "clobbered lock from same host with inactive pid" );

