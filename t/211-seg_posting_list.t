use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 1507;
use File::Spec::Functions qw( catfile );

use KinoSearch::Index::SegPostingList;
use KinoSearch::Index::IndexReader;
use KinoSearch::Index::Term;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex( qw( a b c ), 'c c d' );
my $reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );

my $plist = $reader->posting_list( term => $term );

my ( @docs, @prox );
while ( $plist->next ) {
    my $posting = $plist->get_posting;
    push @docs, $posting->get_doc_num;
    push @prox, $posting->get_prox;
}
is_deeply( \@docs, [ 2, 3 ], "correct docs from SegPList_Next" );
is_deeply( \@prox, [ [0], [ 0, 1 ] ], "correct prox from SegPList_Next" );

$plist->seek($term);
$plist->next;
is( $plist->get_posting->get_doc_num, 2, "seek" );

$plist->set_doc_base(10);
$plist->seek($term);
$plist->next;
is( $plist->get_posting->get_doc_num, 12, "set_doc_base" );
$plist->set_doc_base(0);

$plist->seek($term);
my @postings;
$plist->bulk_read( \@postings, 1024 );
@docs = map { $_->get_doc_num } @postings;
is_deeply( \@docs, [ 2, 3 ], "correct docs from SegPList_Bulk_Read" );
@prox = map { $_->get_prox } @postings;
is_deeply( \@prox, [ [0], [ 0, 1 ] ],
    "correct prox from SegPList_Bulk_Read" );

$plist->seek($term);
$plist->bulk_read( \@postings, 1 );
is( scalar @postings, 1, "bulk_read obeys num_wanted" );

$invindex = KinoSearch::InvIndex->open(
    schema => TestSchema->new,
    folder => KinoSearch::Store::RAMFolder->new,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );

for ( 0 .. 100 ) {
    my $content = 'a ';
    $content .= 'b ' if ( $_ % 2 == 0 );
    $content .= 'c ' if ( $_ % 3 == 0 );
    $content .= 'd ' if ( $_ % 4 == 0 );
    $content .= 'e ' if ( $_ % 5 == 0 );
    $invindexer->add_doc( { content => $content } );
}
$invindexer->finish;
$reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

for my $letter (qw( a b c d e )) {
    $term = KinoSearch::Index::Term->new( 'content', $letter );
    my $skipping_plist = $reader->posting_list( term => $term );
    my $plodding_plist = $reader->posting_list( term => $term );

    # compare results of skip_to() to results of next()
    for my $target ( 0 .. 99 ) {
        $skipping_plist->seek($term);
        $plodding_plist->seek($term);
        $skipping_plist->skip_to($target);
        do {
            $plodding_plist->next or die "shouldn't happen: $target";
        } while ( $plodding_plist->get_doc_num < $target );

        # verify that the plists have identical state
        is( $skipping_plist->get_doc_num,
            $plodding_plist->get_doc_num,
            "$letter: skip to $target"
        );
        is( $skipping_plist->_get_post_stream->stell,
            $plodding_plist->_get_post_stream->stell,
            "$letter: identical filepos for $target"
        );
        is( $skipping_plist->_get_count, $plodding_plist->_get_count,
            "$letter: identical count for $target" );
    }
}

