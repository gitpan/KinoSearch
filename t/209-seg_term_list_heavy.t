use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 3;
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::Index::TermListReader') }

use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::Term;

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
my $seg_infos = KinoSearch::Index::SegInfos->new;
$seg_infos->read_infos($folder);
my $seg_info = $seg_infos->get_info('_1');

my $comp_file_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);
my $tl_reader = KinoSearch::Index::TermListReader->new(
    schema   => $schema,
    folder   => $comp_file_reader,
    seg_info => $seg_info,
);
my $term_list = $tl_reader->start_field_terms('content');

my $term = KinoSearch::Index::Term->new( 'content', 'A' );
$term_list->seek($term);
my $tinfo = $term_list->get_term_info();

is( $tinfo->get_doc_freq, 3, "correct retrieval #1" );

$term = KinoSearch::Index::Term->new( 'content', "Foo" );
$term_list->seek($term);
$tinfo = $term_list->get_term_info();

is( $tinfo->get_doc_freq, 2, "correct retrieval #2" );
