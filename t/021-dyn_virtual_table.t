use strict;
use warnings;

package MyHash;
use base qw( KinoSearch::Util::Hash );

package main;

use Test::More tests => 5;

BEGIN { use_ok("KinoSearch::Util::DynVirtualTable") }

use KinoSearch::Util::Hash;
use KinoSearch::Util::ByteBuf;

my $stringified;
my $storage = KinoSearch::Util::Hash->new;

{
    my $subclassed_hash
        = KinoSearch::Util::DynVirtualTable::_subclass_hash("MyHash");
    $stringified = $subclassed_hash->to_string;

    isa_ok( $subclassed_hash, "MyHash", "Perl isa reports correct subclass" );

    # Store the subclassed object.  At the end of this block, the Perl object
    # will go out of scope and DESTROY will be called, but the kino object
    # will persist.
    $storage->store( "test", $subclassed_hash );
}

my $resurrected = $storage->fetch("test");

isa_ok( $resurrected, "MyHash", "subclass name survived Perl destruction" );
is( $resurrected->to_string, $stringified,
    "It's the same Hash from earlier (though a different Perl object)" );

my $booga = KinoSearch::Util::ByteBuf->new("booga");
$resurrected->store( "ooga", $booga );

is( $resurrected->fetch("ooga")->to_string,
    "booga", "subclassed object still performs correctly at the C level" );

