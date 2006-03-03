use strict;
use warnings;

use lib 't';
use Test::More tests => 7;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::SegTermDocs');
    use_ok('KinoSearch::Index::IndexReader');
}

use KinoSearchTestInvIndex qw( create_invindex );

my $invindex = create_invindex( qw( a b c ), 'c c d' );
my $reader = KinoSearch::Index::IndexReader->new( invindex => $invindex );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );

my $term_docs = $reader->term_docs($term);

my ( $docs, $freqs, $prox );
$term_docs->read( $docs, $freqs, 1024 );

my @doc_nums = unpack( 'I*', $docs );
is_deeply( \@doc_nums, [ 2, 3 ], "correct doc_nums" );

my @freq_nums = unpack( 'I*', $freqs );
is_deeply( \@freq_nums, [ 1, 2 ], "correct freqs" );

$term_docs->set_read_positions(1);
$term_docs->seek($term);
$prox = '';
$prox .= $term_docs->get_positions while $term_docs->next;
my @prox_nums = unpack( 'I*', $prox );
is_deeply( \@prox_nums, [ 0, 0, 1 ], "correct positions" );

$term_docs->_get_deldocs()->set(2);
$term_docs->seek($term);

$term_docs->read( $docs, $freqs, 1024 );
@doc_nums = unpack( 'I*', $docs );
is_deeply( \@doc_nums, [3], "deletions are honored" );

my @documents = ( qw( c ), 'c c d', );
push @documents, "$_ c" for 0 .. 200;

$invindex = create_invindex(@documents);

$reader    = KinoSearch::Index::IndexReader->new( invindex => $invindex );
$term_docs = $reader->term_docs($term);

$term_docs->read( $docs, $freqs, 1024 );
@doc_nums = unpack( 'I*', $docs );
is_deeply( \@doc_nums, [ 0 .. 202 ], "large number of doc_nums correct" );
