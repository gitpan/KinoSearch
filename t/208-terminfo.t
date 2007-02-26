use strict;
use warnings;

use Test::More tests => 19;

BEGIN { use_ok('KinoSearch::Index::TermInfo'); }

my $tinfo = KinoSearch::Index::TermInfo->new( -1, 10, 20, 40, 50 );

my $cloned_tinfo = $tinfo->clone;
ok( !$tinfo->equals($cloned_tinfo),
    "the clone should be a separate C struct" );

is( $tinfo->get_field_num,     -1, "new sets field_num correctly" );
is( $tinfo->get_field_num,     -1, "... field_num cloned" );
is( $tinfo->get_doc_freq,      10, "new sets doc_freq correctly" );
is( $tinfo->get_doc_freq,      10, "... doc_freq cloned" );
is( $tinfo->get_post_fileptr,  20, "new sets post_fileptr correctly" );
is( $tinfo->get_post_fileptr,  20, "... post_fileptr cloned" );
is( $tinfo->get_skip_offset,   40, "new sets skip_offset correctly" );
is( $tinfo->get_skip_offset,   40, "... skip_offset cloned" );
is( $tinfo->get_index_fileptr, 50, "new sets index_fileptr correctly" );
is( $tinfo->get_index_fileptr, 50, "... index_fileptr cloned" );

$tinfo->set_field_num(1000);
is( $tinfo->get_field_num,        1000, "set/get field_num" );
is( $cloned_tinfo->get_field_num, -1,   "setting orig doesn't affect clone" );

$tinfo->set_doc_freq(5);
is( $tinfo->get_doc_freq,        5,  "set/get doc_freq" );
is( $cloned_tinfo->get_doc_freq, 10, "setting orig doesn't affect clone" );

$tinfo->set_post_fileptr(15);
is( $tinfo->get_post_fileptr, 15, "set/get post_fileptr" );

$tinfo->set_skip_offset(35);
is( $tinfo->get_skip_offset, 35, "set/get skip_offset" );

$tinfo->set_index_fileptr(45);
is( $tinfo->get_index_fileptr, 45, "set/get index_fileptr" );
