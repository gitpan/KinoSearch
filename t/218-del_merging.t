use strict;
use warnings;

package DelSchema;
use base 'KinoSearch::Schema';
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    foo => 'text',
    bar => 'text',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;

use Test::More tests => 40;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => DelSchema->new,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc( { foo => 'a', bar => $_ } ) for qw( x y z );
$invindexer->finish;

for my $iter ( 1 .. 10 ) {
    is( search_doc('a'), 3, "match all docs prior to deletion $iter" );
    is( search_doc('x'), 1, "match doc to be deleted $iter" );

    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    $invindexer->delete_by_term( bar => 'x' );
    $invindexer->finish( optimize => 1 );

    is( search_doc('x'), 0, "deletion successful $iter" );
    is( search_doc('a'), 2, "match all docs after deletion $iter" );

    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    $invindexer->add_doc( { foo => 'a', bar => 'x' } );
    $invindexer->finish( optimize => 1 );
}

sub search_doc {
    my $query_string = shift;
    my $searcher     = KinoSearch::Searcher->new( invindex => $invindex );
    my $hits         = $searcher->search( query => $query_string );
    return $hits->total_hits;
}
