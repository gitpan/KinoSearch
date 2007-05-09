use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;
use File::Spec::Functions qw( catfile );

use KinoSearch::Index::SegPostingList;
use KinoSearch::Index::IndexReader;
use KinoSearch::Index::Term;

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
