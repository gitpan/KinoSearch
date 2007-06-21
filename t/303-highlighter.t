use strict;
use warnings;
use lib 'buildlib';

package MySchema::alt;
use base qw( KinoSearch::Schema::FieldSpec );
sub boost {0.1}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    content => 'KinoSearch::Schema::FieldSpec',
    alt     => 'MySchema::alt',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use Test::More tests => 9;

binmode( STDOUT, ":utf8" );

use KinoSearch::Searcher;
use KinoSearch::Highlight::Highlighter;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;

my $phi         = "\x{03a6}";
my $encoded_phi = "&phi;";

my $string = '1 2 3 4 5 ' x 20;    # 200 characters
$string .= "$phi a b c d x y z h i j k ";
$string .= '6 7 8 9 0 ' x 20;
my $with_quotes = '"I see," said the blind man.';
my $invindex    = KinoSearch::InvIndex->clobber(
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
my $highlighter = KinoSearch::Highlight::Highlighter->new;
$highlighter->add_spec( field => 'content' );
$highlighter->add_spec( field => 'alt' );

my $hits = $searcher->search( query => qq|"x y z" AND $phi| );
$hits->create_excerpts( highlighter => $highlighter );
my $hit = $hits->fetch_hit_hashref;
like( $hit->{excerpts}{content},
    qr/$encoded_phi.*?z/i, "excerpt contains all relevant terms" );
like(
    $hit->{excerpts}{content},
    qr#<strong>x y z</strong>#,
    "highlighter tagged the phrase"
);
like(
    $hit->{excerpts}{content},
    qr#<strong>$encoded_phi</strong>#i,
    "highlighter tagged the single term"
);

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

my $term_query = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( content => 'x' ) );
$hits = $searcher->search( query => $term_query );
$hits->create_excerpts( highlighter => $highlighter );
$hit = $hits->fetch_hit_hashref();
like( $hit->{excerpts}{content},
    qr/strong/, "specify field highlights correct field..." );
unlike( $hit->{excerpts}{alt}, qr/strong/, "... but not another field" );
