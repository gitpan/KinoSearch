use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 38;
use Storable qw( freeze thaw );
use KinoSearch::Test::Util::TestCharBuf qw( vcatf_tests );
use KinoSearch::Test::TestUtils qw( utf8_test_strings );

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

sub get_cb { KinoSearch::Util::CharBuf->new(shift) }

my $charbuf = get_cb($smiley);
isa_ok( $charbuf, "KinoSearch::Util::CharBuf" );
is( $charbuf->to_perl, $smiley, "round trip UTF-8" );

my $frowny_charbuf = get_cb($frowny);
$charbuf->cat($frowny_charbuf);
is( $charbuf->to_perl, "$smiley$frowny", "cat" );
$charbuf->copy($frowny_charbuf);
is( $charbuf->to_perl, $frowny, "copy" );

$charbuf = get_cb($smiley);
my $dupe = thaw( freeze($charbuf) );
isa_ok( $dupe, "KinoSearch::Util::CharBuf",
    "thaw/freeze produces correct object" );
is( $dupe->to_perl, $charbuf->to_perl, "freeze/thaw" );

my $clone = $charbuf->clone;
is( $clone->to_perl, get_cb($smiley)->to_perl, "clone" );

my $string = "a$smiley$smiley" . "b$smiley" . "c";
$charbuf = get_cb($string);
is( $charbuf->code_point_at(4),   ord $smiley, "code_point_at" );
is( $charbuf->code_point_at(2),   ord $smiley, "code_point_from" );
is( $charbuf->code_point_from(3), ord 'b',     "code_point_from" );
is( $charbuf->substring( offset => 2, len => 3 ),
    substr( $string, 2, 3 ), "substring" );

$charbuf->nip(2);
is( $charbuf->to_perl, substr( $string, 2 ), "nip" );
$charbuf->chop(3);
my $len = length $charbuf->to_perl;
is( length $charbuf->to_perl, length($string) - 5, "chop" );

my $spaces
    = " \t\r\x{000A}\x{000B}\x{000C}\x{000D}\x{0085}"
    . "\x{00A0}\x{1680}\x{180E}\x{2000}\x{2001}\x{2002}\x{2003}\x{2004}"
    . "\x{2005}\x{2006}\x{2007}\x{2008}\x{2009}\x{200A}\x{2028}\x{2029}"
    . "\x{202F}\x{205F}\x{3000}";
$charbuf = get_cb( $spaces . $smiley . $spaces );
ok( $charbuf->trim_top,,  "trim_top returns true on success" );
ok( !$charbuf->trim_top,, "trim_top returns false on failure" );
ok( $charbuf->trim_tail,  "trim_tail returns true on success" );
ok( !$charbuf->trim_tail, "trim_tail returns false on failure" );
is( $charbuf->to_perl, $smiley, "trim_top and trim_tail worked" );
$charbuf->cat( get_cb($spaces) );
ok( $charbuf->trim,  "trim true on success" );
ok( !$charbuf->trim, "trim false on failure" );
is( $charbuf->to_perl, $smiley, "trim worked" );
$charbuf->cat_char( ord($smiley) );
$charbuf->cat_char( ord($smiley) );
is( $charbuf->to_perl, "$smiley$smiley$smiley", "cat_char" );
$charbuf->truncate(2);
is( $charbuf->to_perl, "$smiley$smiley", "truncate" );

for my $case ( @{ vcatf_tests() } ) {
    is( $case->get_got, $case->get_wanted );
}

$charbuf = get_cb("1.5");
my $difference = 1.5 - $charbuf->to_f64;
$difference = -$difference if $difference < 0;
cmp_ok( $difference, '<', 0.001, "To_F64" );

my $ram_file  = KinoSearch::Store::RAMFileDes->new;
my $outstream = KinoSearch::Store::OutStream->new($ram_file);
$charbuf->serialize($outstream);
$outstream->close;
my $instream     = KinoSearch::Store::InStream->new($ram_file);
my $deserialized = KinoSearch::Util::CharBuf->deserialize($instream);
is_deeply( $charbuf->to_perl, $deserialized->to_perl,
    "serialize/deserialize" );

