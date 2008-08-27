use strict;
use warnings;

use lib 't';
use Test::More tests => 1;
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::Index::SegInfos') }
use KinoSearchTestInvIndex qw( create_invindex );

create_invindex( "a", "a b" );

my $sinfos = KinoSearch::Index::SegInfos->new;

