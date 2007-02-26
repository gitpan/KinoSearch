use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::Index::SegInfos') }
use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex( "a", "a b" );

my $seg_infos = KinoSearch::Index::SegInfos->new;
$seg_infos->read_infos( $invindex->get_folder );
$seg_infos->write_infos( $invindex->get_folder );

# there's not a lot we can test on SegInfos.
pass("successfully read and wrote infos without crashing");

