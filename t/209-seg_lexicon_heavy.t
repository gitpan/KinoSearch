use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

use KinoSearch::Index::LexReader;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::Term;
use KinoSearch::Index::SegInfos;

use KinoTestUtils qw( create_invindex );
use KinoSearch::Util::YAML qw( parse_yaml );

my @docs;
my @chars = ( 'a' .. 'z' );
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
my $invindex = create_invindex(
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

my $folder    = $invindex->get_folder;
my $schema    = $invindex->get_schema;
my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos( folder => $folder );
my $seg_info = $seg_infos->get_info('_1');

my $comp_file_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);
my $lex_reader = KinoSearch::Index::LexReader->new(
    schema   => $schema,
    folder   => $comp_file_reader,
    seg_info => $seg_info,
);

my $lexicon = $lex_reader->look_up_field('content');
$lexicon->next;
my $last_text = $lexicon->get_term->get_text;
$lexicon->next;
my $current_text;
my $num_iters = 2;
while (1) {
    $current_text = $lexicon->get_term->get_text;
    last unless $current_text gt $last_text;
    last unless $lexicon->next;
    $num_iters++;
    $current_text = $last_text;
}
cmp_ok( $last_text, 'lt', $current_text, "term texts in sorted order" );
is( $num_iters, $lexicon->get_size, "iterated over all terms" );

my $term = KinoSearch::Index::Term->new( 'content', 'A' );
$lexicon->seek($term);
my $tinfo = $lexicon->get_term_info();

is( $tinfo->get_doc_freq, 3, "correct retrieval #1" );

$term = KinoSearch::Index::Term->new( 'content', "Foo" );
$lexicon->seek($term);
$tinfo = $lexicon->get_term_info();

is( $tinfo->get_doc_freq, 2, "correct retrieval #2" );
