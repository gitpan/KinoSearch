use strict;
use warnings;
use lib 'buildlib';

package MySchema::content;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema::alt;
use base qw( KinoSearch::Schema::FieldSpec );
sub boost {0.1}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }
__PACKAGE__->init_fields(qw( content alt ));

package main;

use Test::More tests => 7;

binmode( STDOUT, ":utf8" );

use KinoSearch::Searcher;
use KinoSearch::Highlight::Highlighter;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;

my $string = '1 2 3 4 5 ' x 20;    # 200 characters
$string .= "\x{03a6} a b c d x y z h i j k ";
$string .= '6 7 8 9 0 ' x 20;
my $with_quotes = '"I see," said the blind man.';
my $invindex    = KinoSearch::InvIndex->create(
    folder => KinoSearch::Store::RAMFolder->new,
    schema => MySchema->new,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->add_doc( { content => $_ } ) for ( $string, $with_quotes );
$invindexer->add_doc(
    {   content => "x but not why or 2ee",
        alt     => $string . " and extra stuff so it scores lower",
    }
);
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
my $highlighter = KinoSearch::Highlight::Highlighter->new(
    fields => [qw( content alt )] );

my $hits = $searcher->search( query => qq|"x y z" AND \x{03a6}| );
$hits->create_excerpts( highlighter => $highlighter );
$hits->seek( 0, 2 );
my $hit = $hits->fetch_hit_hashref;
like( $hit->{excerpts}{content},
    qr/\x{03a6}.*?z/, "excerpt contains all relevant terms" );
like(
    $hit->{excerpts}{content},
    qr#<strong>x y z</strong>#,
    "highlighter tagged the phrase"
);
like( $hit->{excerpts}{content},
    qr#<strong>\x{03a6}</strong>#, "highlighter tagged the single term" );

like( $hits->fetch_hit_hashref()->{excerpts}{content},
    qr/x/,
    "excerpt field with partial hit doesn't cause highlighter freakout" );

$hits = $searcher->search( query => 'x "x y z" AND b' );
$hits->create_excerpts( highlighter => $highlighter );
$hits->seek( 0, 2 );
like( $hits->fetch_hit_hashref()->{excerpts}{content},
    qr/x y z/,
    "query with same word in both phrase and term doesn't cause freakout" );

$hits = $searcher->search( query => 'blind' );
$hits->create_excerpts( highlighter => $highlighter );
like( $hits->fetch_hit_hashref()->{excerpts}{content},
    qr/quot/, "HTML entity encoded properly" );

$hits = $searcher->search( query => 'why' );
$hits->create_excerpts( highlighter => $highlighter );
unlike( $hits->fetch_hit_hashref()->{excerpts}{content},
    qr/\.\.\./, "no ellipsis for short excerpt" );

