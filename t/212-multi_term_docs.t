use strict;
use warnings;

package MySchema;
use base qw( KinoSearch::Schema );

our %FIELDS = (
    content => 'KinoSearch::Schema::FieldSpec',
    id      => 'KinoSearch::Schema::FieldSpec',
);

use KinoSearch::Analysis::Tokenizer;

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 9;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::SegTermDocs');
    use_ok('KinoSearch::Index::MultiTermDocs');
    use_ok('KinoSearch::Index::IndexReader');
    use_ok('KinoSearch::InvIndexer');
    use_ok('KinoSearch::Store::RAMFolder');
}

my $folder   = KinoSearch::Store::RAMFolder->new();
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->create(
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

my $ix_reader = KinoSearch::Index::IndexReader->new( invindex => $invindex );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );
my $term_docs = $ix_reader->term_docs($term);
my ( $docs, $freqs, $prox ) = ( '', '', '' );
my ( $d, $fb, $f, $p, $b );
while ( $term_docs->bulk_read( $d, $fb, $f, $p, $b, 1024 ) ) {
    $docs  .= $d;
    $freqs .= $f;
    $prox  .= $p;
}
my @doc_nums = unpack( 'I*', $docs );
is_deeply( \@doc_nums, [ 2, 27, 52, 77 ], "correct doc_nums" );

my @freq_nums = unpack( 'I*', $freqs );
is_deeply( \@freq_nums, [ 1, 2, 3, 4 ], "correct freqs" );
my @prox_nums = unpack( 'I*', $prox );
is_deeply(
    \@prox_nums,
    [ 0, 0, 1, 0, 1, 2, 0, 1, 2, 3 ],
    "correct positions"
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->delete_by_term( id => 52 );
$invindexer->finish;
$ix_reader = KinoSearch::Index::IndexReader->new( invindex => $invindex );
$term_docs = $ix_reader->term_docs($term);
@doc_nums  = ();
push @doc_nums, $term_docs->get_doc, while $term_docs->next;
is_deeply( \@doc_nums, [ 2, 27, 77 ], "deletions handled properly" );
