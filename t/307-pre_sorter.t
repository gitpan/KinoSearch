use strict;
use warnings;

use Test::More tests => 9;

package PreSortField;
use base qw( KinoSearch::FieldSpec::text );
sub analyzed {0}

package PreSortSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( letter => 'PreSortField' );

sub pre_sort { return { field => 'letter', reverse => 1 } }
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;
use KinoSearch::Store::LockFactory;
use KinoSearch::Index::PreSorter;
use KinoSearch::Searcher;
use List::Util qw( shuffle );

my @docs = qw( c b d a );

my $pre_sorter = KinoSearch::Index::PreSorter->new( field => 'foo' );
my $count = 0;
$pre_sorter->add_val( $count++, $_ ) for @docs;
my $map = $pre_sorter->gen_remap;
my @got = map { $map->get($_) } 0 .. 3;
is_deeply( \@got, [ 2, 1, 3, 0 ], "remap" );

$pre_sorter
    = KinoSearch::Index::PreSorter->new( field => 'foo', reverse => 1 );
$count = 0;
$pre_sorter->add_val( $count++, $_ ) for @docs;
$map = $pre_sorter->gen_remap;
@got = map { $map->get($_) } 0 .. 3;
is_deeply( \@got, [ 1, 2, 0, 3 ], "reverse sort" );

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = PreSortSchema->new;

my $invindex = KinoSearch::InvIndex->clobber(
    schema => $schema,
    folder => $folder,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
my @originals = shuffle 'a' .. 'j';
$invindexer->add_doc( { letter => $_ } ) for @originals;
$invindexer->finish;

my $reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );
@got = map { $reader->fetch_doc($_)->{letter} } 0 .. 9;
is_deeply( \@got, [ reverse 'a' .. 'j' ], "DocWriter pre-sorts correctly" );

@got = ();
my $doc_num = 9;
for my $letter ( 'a' .. 'j' ) {
    my $doc_vec = $reader->fetch_doc_vec($doc_num);
    my $term_vector = $doc_vec->term_vector( 'letter', $letter );
    push @got, $term_vector->get_start_offsets->[0];
    $doc_num--;
}
is_deeply( \@got, [ (0) x 10 ], "TVWriter pre-sorts correctly" );

test_search( "single seg", 'a' .. 'j' );

$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
$invindexer->add_doc( { letter => $_ } ) for shuffle( 'k' .. 't' );
$invindexer->finish;
$reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

@got = map { $reader->fetch_doc($_)->{letter} } 0 .. 19;
is_deeply(
    \@got,
    [ reverse( 'a' .. 'j' ), reverse( 'k' .. 't' ) ],
    "DocWriter multi-seg"
);

test_search( "multi-seg", 'a' .. 't' );

$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
#$invindexer->delete_by_term('letter', 'd');
$invindexer->add_doc( { letter => $_ } ) for shuffle( 'u' .. 'z' );
$invindexer->finish( optimize => 1 );
$reader = KinoSearch::Index::IndexReader->open( invindex => $invindex );

@got = map { $reader->fetch_doc($_)->{letter} } 0 .. 25;
is_deeply( \@got, [ reverse( 'a' .. 'z' ) ], "DocWriter after optimizing" );

test_search( "after optimizing", 'a' .. 'c', 'e' .. 'z' );

sub test_search {
    my ( $message, @letters ) = @_;

    @got = ();
    my $searcher = KinoSearch::Searcher->new( reader => $reader );
    for (@letters) {
        my $hits = $searcher->search( query => $_ );
        push @got, $hits->fetch_hit_hashref->{letter};
    }
    is_deeply( \@got, \@letters, "test search $message" );
}
