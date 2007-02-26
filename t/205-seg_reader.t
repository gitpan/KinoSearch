use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 6;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::IndexReader');
    use_ok('KinoSearch::Index::Term');
}

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex(
    "What's he building in there?",
    "What's he building in there?",
    "We have a right to know."
);

my $ix_reader = KinoSearch::Index::IndexReader->new( invindex => $invindex );

isa_ok(
    $ix_reader,
    'KinoSearch::Index::SegReader',
    "single segment indexes cause new to return a SegReader"
);

is( $ix_reader->max_doc, 3, "max_doc returns correct number" );

my $term = KinoSearch::Index::Term->new( 'content', 'building' );
my $term_list = $ix_reader->field_terms($term);
isa_ok( $term_list, 'KinoSearch::Index::TermList',
    "field_terms returns a TermList" );
my $tinfo = $term_list->get_term_info;
is( $tinfo->get_doc_freq, 2, "correct place in enum" );
