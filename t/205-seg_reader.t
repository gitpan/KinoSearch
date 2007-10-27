use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

use KinoSearch::Index::IndexReader;
use KinoSearch::Index::Term;

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex(
    "What's he building in there?",
    "What's he building in there?",
    "We have a right to know."
);

my $reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

isa_ok(
    $reader,
    'KinoSearch::Index::SegReader',
    "single segment indexes cause new to return a SegReader"
);

is( $reader->max_doc, 3, "max_doc returns correct number" );

my $term = KinoSearch::Index::Term->new( 'content', 'building' );
my $lexicon = $reader->look_up_term($term);
isa_ok( $lexicon, 'KinoSearch::Index::Lexicon',
    "look_up_term returns a KinoSearch::Index::Lexicon" );
my $tinfo = $lexicon->get_term_info;
is( $tinfo->get_doc_freq, 2, "correct place in enum" );
