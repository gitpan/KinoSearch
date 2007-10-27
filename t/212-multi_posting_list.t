use strict;
use warnings;

package MySchema;
use base qw( KinoSearch::Schema );

our %fields = (
    content => 'text',
    id      => 'text',
);

use KinoSearch::Analysis::Tokenizer;

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 4;

use KinoSearch::Index::MultiPostingList;
use KinoSearch::Index::IndexReader;
use KinoSearch::Index::Term;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;

my $folder   = KinoSearch::Store::RAMFolder->new();
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);

my $id = 0;
for my $iter ( 1 .. 4 ) {
    my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    for my $letter ( 'a' .. 'y' ) {
        my $content = ( "$letter " x $iter ) . 'z';
        $invindexer->add_doc(
            {   content => $content,
                id      => $id++,
            }
        );
    }
    $invindexer->finish;
}

my $reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );
my $plist = $reader->posting_list( term => $term );

my @doc_nums;
my @freqs;
my @prox;
while ( $plist->next ) {
    my $posting = $plist->get_posting;
    push @doc_nums, $posting->get_doc_num;
    push @freqs,    $posting->get_freq;
    push @prox,     @{ $posting->get_prox };
}
is_deeply( \@doc_nums, [ 2, 27, 52, 77 ], "correct doc_nums" );

is_deeply( \@freqs, [ 1, 2, 3, 4 ], "correct freqs" );
is_deeply( \@prox, [ 0, 0, 1, 0, 1, 2, 0, 1, 2, 3 ], "correct positions" );

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->delete_by_term( id => 52 );
$invindexer->finish;
$reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );
$plist = $reader->posting_list( term => $term );
@doc_nums = ();
push @doc_nums, $plist->get_posting->get_doc_num while $plist->next;
is_deeply( \@doc_nums, [ 2, 27, 77 ], "deletions handled properly" );

