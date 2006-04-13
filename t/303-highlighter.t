use strict;
use warnings;

use lib 't';
use Test::More tests => 6;

BEGIN {
    use_ok('KinoSearch::Searcher');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Highlight::Highlighter');
}

use KinoSearchTestInvIndex qw( create_invindex );

my $string = '1 2 3 4 5 ' x 20;    # 200 characters
$string .= 'a b c d x y z h i j k ';
$string .= '6 7 8 9 0 ' x 20;
my $invindex = create_invindex($string);

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;
my $searcher  = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => $tokenizer,
);
my $highlighter
    = KinoSearch::Highlight::Highlighter->new( excerpt_field => 'content', );

my $hits = $searcher->search( query => '"x y z" AND b' );
$hits->create_excerpts( highlighter => $highlighter );
$hits->seek( 0, 1 );
my $hit = $hits->fetch_hit_hashref;
like( $hit->{excerpt}, qr/b.*?z/, "excerpt contains all relevant terms" );
like(
    $hit->{excerpt},
    qr#<strong>x</strong> <strong>y</strong> <strong>z</strong>#,
    "highlighter taggeed the phrase"
);
like( $hit->{excerpt}, qr#<strong>b</strong>#,
    "highlighter tagged the single term" );
