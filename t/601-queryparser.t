#!/usr/bin/perl
use strict;
use warnings;

use lib 't';
use KinoSearch qw( kdump );
use Test::More 'no_plan';
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::QueryParser::QueryParser') }

use KinoSearchTestInvIndex qw( create_invindex );
use KinoSearch::Searcher;
use KinoSearch::Analysis::Tokenizer;

my $whitespace_tokenizer
    = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/ );

my $OR_parser = KinoSearch::QueryParser::QueryParser->new(
    analyzer      => $whitespace_tokenizer,
    default_field => 'content',
);
my $AND_parser = KinoSearch::QueryParser::QueryParser->new(
    analyzer       => $whitespace_tokenizer,
    default_field  => 'content',
    default_boolop => 'AND',
);

my @docs     = ( 'x', 'y', 'z', 'x a', 'x a b', 'x a b c', 'x a b c d', );
my $invindex = create_invindex(@docs);

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my @logical_tests = (

    'b'     => [ 3, 3, ],
    '(a)'   => [ 4, 4, ],
    '"a"'   => [ 4, 4, ],
    '"(a)"' => [ 0, 0, ],
    '("a")' => [ 4, 4, ],

    'a b'     => [ 4, 3, ],
    'a (b)'   => [ 4, 3, ],
    'a "b"'   => [ 4, 3, ],
    'a ("b")' => [ 4, 3, ],
    'a "(b)"' => [ 4, 0, ],

    '(a b)'   => [ 4, 3, ],
    '"a b"'   => [ 3, 3, ],
    '("a b")' => [ 3, 3, ],
    '"(a b)"' => [ 0, 0, ],

    'a b c'     => [ 4, 2, ],
    'a (b c)'   => [ 4, 2, ],
    'a "b c"'   => [ 4, 2, ],
    'a ("b c")' => [ 4, 2, ],
    'a "(b c)"' => [ 4, 0, ],
    '"a b c"'   => [ 2, 2, ],

    '-x'     => [ 0, 0, ],
    'x -c'   => [ 3, 3, ],
    'x "-c"' => [ 5, 0, ],
    'x +c'   => [ 2, 2, ],
    'x "+c"' => [ 5, 0, ],

    '+x +c' => [ 2, 2, ],
    '+x -c' => [ 3, 3, ],
    '-x +c' => [ 0, 0, ],
    '-x -c' => [ 0, 0, ],

    'x y'     => [ 6, 0, ],
    'x a d'   => [ 5, 1, ],
    'x "a d"' => [ 5, 0, ],

    'x AND y'     => [ 0, 0, ],
    'x OR y'      => [ 6, 6, ],
    'x AND NOT y' => [ 5, 5, ],

    'x (b OR c)'     => [ 5, 3, ],
    'x AND (b OR c)' => [ 3, 3, ],
    'x OR (b OR c)'  => [ 5, 5, ],
    'x (y OR c)'     => [ 6, 2, ],
    'x AND (y OR c)' => [ 2, 2, ],

    'a AND NOT (b OR "c d")'     => [ 1, 1, ],
    'a AND NOT "a b"'            => [ 1, 1, ],
    'a AND NOT ("a b" OR "c d")' => [ 1, 1, ],

    '+"b c" -d' => [ 1, 1, ],
    '"a b" +d'  => [ 1, 1, ],

    'x AND NOT (b OR (c AND d))' => [ 2, 2, ],

    '-(+foo)' => [ 0, 0 ],

);

do {
    my $i = 0;
    while ( $i < @logical_tests ) {
        my $qstring     = $logical_tests[ $i++ ];
        my $OR_expected = $logical_tests[$i][0];
        my $query       = $OR_parser->parse($qstring);
        my $hits        = $searcher->search( query => $query );
        $hits->seek( 0, 50 );
        is( $hits->total_hits, $OR_expected, "OR:    $qstring" );

        $query = $AND_parser->parse($qstring);
        my $AND_expected = $logical_tests[ $i++ ][1];
        $hits = $searcher->search( query => $query );
        $hits->seek( 0, 50 );
        is( $hits->total_hits, $AND_expected, "AND:   $qstring" );
        $hits->{searcher} = undef, $hits->{reader} = undef,
            $hits->{weight} = undef,
            # kdump($query);
            # exit;
    }

    }

