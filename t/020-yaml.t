use strict;
use warnings;

use Test::More tests => 35;

BEGIN { use_ok( "KinoSearch::Util::YAML" => 'encode_yaml', 'parse_yaml' ) }

use KinoSearch::Util::ByteBuf;
use KinoSearch::Util::Obj;
use KinoSearch::Util::Hash;
use KinoSearch::Util::VArray;

sub parse_and_deparse {
    my ( $scalar_input, $expected, $message ) = @_;
    my $got = parse_yaml($scalar_input);
    is_deeply( $got, $expected, $message );

    my $encoded = encode_yaml($expected);
    $| = 1;
    is_deeply( parse_yaml($encoded), $expected, $message );
}

is( parse_yaml(""), undef, "blank file" );

parse_and_deparse( "foo : bar\n", { foo => 'bar' }, "simple hash" );

parse_and_deparse( "foo : bar", { foo => 'bar' }, "no newline" );

parse_and_deparse( "'': ''", { '' => '' }, "blank strings" );

parse_and_deparse(
    "\n\na: foo\n\n\nb: bar\n\n",
    { a => 'foo', b => 'bar' },
    "extra blank lines"
);

parse_and_deparse(
    "  a: foo\n  b: bar\n",
    { a => 'foo', b => 'bar' },
    "initial indent > 0"
);

parse_and_deparse(
    "foo : bar # comment\n",
    { foo => 'bar' },
    "line end comment"
);

parse_and_deparse(
    "'foo ball' : 'bar'\n",
    { 'foo ball' => 'bar' },
    "quoted key and value"
);

parse_and_deparse(
    "'foo''s ball' : bar \n",
    { 'foo\'s ball' => 'bar' },
    "escaped single quote"
);

parse_and_deparse( "- foo \n- bar \n- baz \n",
    [qw( foo bar baz )], "simple array" );

parse_and_deparse( "- foo", [qw( foo )], "no newline" );

# multi-level

parse_and_deparse(
    "-\n  - foo\n  - bar\n",
    [ [qw(foo bar)] ],
    "array of arrays"
);

parse_and_deparse(
    "first: \n  a: foo\n  b: bar\n",
    { first => { a => 'foo', b => 'bar' } },
    "hash of hashes"
);

my $source = qq|
  first:
    - foo
    - bar
  second:
    - baz
    - boffo|;
parse_and_deparse(
    $source,
    { first => [qw( foo bar )], second => [qw( baz boffo )] },
    "hash of arrays"
);

$source = qq|
  -
    a: foo
    b: bar
  - 
    c: baz
    d: boffo|;
parse_and_deparse(
    $source,
    [ { a => 'foo', b => 'bar' }, { c => 'baz', d => 'boffo' } ],
    "array of hashes"
);

# invalid entries

SKIP: {
    skip( "known leaks", 5 ) if $ENV{KINO_VALGRIND};

    eval { parse_yaml("-foo\n"); };
    like( $@, qr/array/, "no space between dash and scalar" );

    eval { parse_yaml("- \n"); };
    like( $@, qr/array/, "missing array element" );

    eval { parse_yaml("foo:"); };
    like( $@, qr/hash/, "missing hash value" );

    eval { encode_yaml("") };
    like( $@, qr/ByteBuf/, "supplying scalar to encode_yaml fails" );

    eval { encode_yaml( { "foo\n:" => "bar" } ) };
    like( $@, qr/invalid/, "invalid character in scalar" );
}

