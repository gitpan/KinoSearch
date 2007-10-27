use strict;
use warnings;

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

our %fields = ();

package main;

use Test::More tests => 10;

use KinoSearch::Store::RAMFolder;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;

my $schema = MySchema->new;

for my $num_fields ( 1 .. 10 ) {
    # build an invindex with $num_fields fields, and the same content in each
    $schema->add_field( "field$num_fields" => 'text' );
    my $folder   = KinoSearch::Store::RAMFolder->new;
    my $invindex = KinoSearch::InvIndex->clobber(
        schema => $schema,
        folder => $folder,
    );

    my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
    for my $content ( 'a' .. 'z', 'x x y' ) {
        my %doc;
        for ( 1 .. $num_fields ) {
            $doc{"field$_"} = $content;
        }
        $invindexer->add_doc( \%doc );
    }
    $invindexer->finish;

    # see if our search results match as expected.
    my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
    my $hits = $searcher->search(
        query      => 'x',
        num_wanted => 100,
    );
    is( $hits->total_hits, 2,
        "correct number of hits for $num_fields fields" );
    my $top_hit = $hits->fetch_hit_hashref;
}
