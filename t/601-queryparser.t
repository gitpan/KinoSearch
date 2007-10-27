use strict;
use warnings;
use lib 'buildlib';

package PlainSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'text' );

sub analyzer { KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/ ) }

package StopSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::Stopalizer;

our %fields = ( content => 'text' );

sub analyzer {
    my $whitespace_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/ );
    my $stopalizer
        = KinoSearch::Analysis::Stopalizer->new( stoplist => { x => 1 } );
    return KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $whitespace_tokenizer, $stopalizer, ], );
}

package main;
use Test::More tests => 219;

use KinoSearch::QueryParser;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Util::StringHelper qw( utf8_flag_on utf8ify );

use KinoTestUtils qw( create_invindex );

my $folder       = KinoSearch::Store::RAMFolder->new;
my $stop_folder  = KinoSearch::Store::RAMFolder->new;
my $plain_schema = PlainSchema->new;
my $stop_schema  = StopSchema->new;
my $invindex     = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $plain_schema,
);
my $stop_invindex = KinoSearch::InvIndex->clobber(
    folder => $stop_folder,
    schema => $stop_schema,
);

my @docs = ( 'x', 'y', 'z', 'x a', 'x a b', 'x a b c', 'x foo a b c d', );
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
my $stop_invindexer
    = KinoSearch::InvIndexer->new( invindex => $stop_invindex, );

for (@docs) {
    $invindexer->add_doc(      { content => $_ } );
    $stop_invindexer->add_doc( { content => $_ } );
}
$invindexer->finish;
$stop_invindexer->finish;

my $OR_parser = KinoSearch::QueryParser->new( schema => $plain_schema, );
my $AND_parser = KinoSearch::QueryParser->new(
    schema         => $plain_schema,
    default_boolop => 'AND',
);
$OR_parser->set_heed_colons(1);
$AND_parser->set_heed_colons(1);

my $OR_stop_parser = KinoSearch::QueryParser->new( schema => $stop_schema, );
my $AND_stop_parser = KinoSearch::QueryParser->new(
    schema         => $stop_schema,
    default_boolop => 'AND',
);
$OR_stop_parser->set_heed_colons(1);
$AND_stop_parser->set_heed_colons(1);

my $searcher      = KinoSearch::Searcher->new( invindex => $invindex );
my $stop_searcher = KinoSearch::Searcher->new( invindex => $stop_invindex );

my @logical_tests = (

    'b'     => [ 3, 3, 3, 3, ],
    '(a)'   => [ 4, 4, 4, 4, ],
    '"a"'   => [ 4, 4, 4, 4, ],
    '"(a)"' => [ 0, 0, 0, 0, ],
    '("a")' => [ 4, 4, 4, 4, ],

    'a b'     => [ 4, 3, 4, 3, ],
    'a (b)'   => [ 4, 3, 4, 3, ],
    'a "b"'   => [ 4, 3, 4, 3, ],
    'a ("b")' => [ 4, 3, 4, 3, ],
    'a "(b)"' => [ 4, 0, 4, 0, ],

    '(a b)'   => [ 4, 3, 4, 3, ],
    '"a b"'   => [ 3, 3, 3, 3, ],
    '("a b")' => [ 3, 3, 3, 3, ],
    '"(a b)"' => [ 0, 0, 0, 0, ],

    'a b c'     => [ 4, 2, 4, 2, ],
    'a (b c)'   => [ 4, 2, 4, 2, ],
    'a "b c"'   => [ 4, 2, 4, 2, ],
    'a ("b c")' => [ 4, 2, 4, 2, ],
    'a "(b c)"' => [ 4, 0, 4, 0, ],
    '"a b c"'   => [ 2, 2, 2, 2, ],

    '-x'     => [ 0, 0, 0, 0, ],
    'x -c'   => [ 3, 3, 0, 0, ],
    'x "-c"' => [ 5, 0, 0, 0, ],
    'x +c'   => [ 2, 2, 2, 2, ],
    'x "+c"' => [ 5, 0, 0, 0, ],

    '+x +c' => [ 2, 2, 2, 2, ],
    '+x -c' => [ 3, 3, 0, 0, ],
    '-x +c' => [ 0, 0, 2, 2, ],
    '-x -c' => [ 0, 0, 0, 0, ],

    'x y'     => [ 6, 0, 1, 1, ],
    'x a d'   => [ 5, 1, 4, 1, ],
    'x "a d"' => [ 5, 0, 0, 0, ],
    '"x a"'   => [ 3, 3, 4, 4, ],

    'x AND y'     => [ 0, 0, 1, 1, ],
    'x OR y'      => [ 6, 6, 1, 1, ],
    'x AND NOT y' => [ 5, 5, 0, 0, ],

    'x (b OR c)'     => [ 5, 3, 3, 3, ],
    'x AND (b OR c)' => [ 3, 3, 3, 3, ],
    'x OR (b OR c)'  => [ 5, 5, 3, 3, ],
    'x (y OR c)'     => [ 6, 2, 3, 3, ],
    'x AND (y OR c)' => [ 2, 2, 3, 3, ],

    'a AND NOT (b OR "c d")'     => [ 1, 1, 1, 1, ],
    'a AND NOT "a b"'            => [ 1, 1, 1, 1, ],
    'a AND NOT ("a b" OR "c d")' => [ 1, 1, 1, 1, ],

    '+"b c" -d' => [ 1, 1, 1, 1, ],
    '"a b" +d'  => [ 1, 1, 1, 1, ],

    'x AND NOT (b OR (c AND d))' => [ 2, 2, 0, 0, ],

    '-(+notthere)' => [ 0, 0, 0, 0 ],

    'content:b'              => [ 3, 3, 3, 3, ],
    'bogusfield:a'           => [ 0, 0, 0, 0, ],
    'bogusfield:a content:b' => [ 3, 0, 3, 0, ],

    'content:b content:c' => [ 3, 2, 3, 2 ],
    'content:(b c)'       => [ 3, 2, 3, 2 ],
    'bogusfield:(b c)'    => [ 0, 0, 0, 0 ],

);

my $i = 0;
while ( $i < @logical_tests ) {
    my $qstring = $logical_tests[$i];
    $i++;

    my $query = $OR_parser->parse($qstring);
    my $hits = $searcher->search( query => $query );
    is( $hits->total_hits, $logical_tests[$i][0], "OR:    $qstring" );

    $query = $AND_parser->parse($qstring);
    $hits = $searcher->search( query => $query );
    is( $hits->total_hits, $logical_tests[$i][1], "AND:   $qstring" );

    $query = $OR_stop_parser->parse($qstring);
    $hits = $stop_searcher->search( query => $query );
    is( $hits->total_hits, $logical_tests[$i][2], "stoplist-OR:   $qstring" );

    $query = $AND_stop_parser->parse($qstring);
    $hits = $stop_searcher->search( query => $query );
    is( $hits->total_hits, $logical_tests[$i][3],
        "stoplist-AND:   $qstring" );

    $i++;
}

my $motorhead = "Mot\xF6rhead";
utf8ify($motorhead);
my $unicode_invindex = create_invindex($motorhead);
$searcher = KinoSearch::Searcher->new( invindex => $unicode_invindex, );

my $hits = $searcher->search( query => 'Mot' );
is( $hits->total_hits, 0, "Pre-test - indexing worked properly" );
$hits = $searcher->search( query => $motorhead );
is( $hits->total_hits, 1, "QueryParser parses UTF-8 strings correctly" );

use KinoSearch::QueryParser::QueryParser;
my $compat_parser
    = KinoSearch::QueryParser::QueryParser->new( schema => PlainSchema->new );
isa_ok( $compat_parser, 'KinoSearch::QueryParser' );

