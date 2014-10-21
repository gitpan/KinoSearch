use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 3;
use KinoSearch::Test::TestUtils qw( create_index );

my @docs;
my @chars = ( 'a' .. 'z', 'B' .. 'E', 'G' .. 'Z' );
for ( 0 .. 1000 ) {
    my $content = '';
    for my $num_words ( 0 .. int( rand(20) ) ) {
        for my $num_chars ( 1 .. int( rand(10) ) ) {
            $content .= @chars[ rand(@chars) ];
        }
        $content .= ' ';
    }
    push @docs, "$content\n";
}
my $folder = create_index(
    ( 1 .. 1000 ),
    ( ("a") x 100 ),
    "Foo",
    @docs,
    "Foo",
    "A MAN",
    "A PLAN",
    "A CANAL",
    "PANAMA"
);
my $schema = KinoSearch::Test::TestSchema->new;

my $snapshot
    = KinoSearch::Index::Snapshot->new->read_file( folder => $folder );
my $segment = KinoSearch::Index::Segment->new( number => 1 );
$segment->read_file($folder);
my $lex_reader = KinoSearch::Index::DefaultLexiconReader->new(
    schema   => $schema,
    folder   => $folder,
    snapshot => $snapshot,
    segments => [$segment],
    seg_tick => 0,
);

my $lexicon = $lex_reader->lexicon( field => 'content' );
$lexicon->next;
my $last_text = $lexicon->get_term;
$lexicon->next;
my $current_text;
my $num_iters = 2;
while (1) {
    $current_text = $lexicon->get_term;
    last unless $current_text gt $last_text;
    last unless $lexicon->next;
    $num_iters++;
    $current_text = $last_text;
}
cmp_ok( $last_text, 'lt', $current_text, "term texts in sorted order" );

$lexicon->seek('A');
my $tinfo = $lexicon->get_term_info();
is( $tinfo->get_doc_freq, 3, "correct retrieval #1" );

$lexicon->seek('Foo');
$tinfo = $lexicon->get_term_info();
is( $tinfo->get_doc_freq, 2, "correct retrieval #2" );
