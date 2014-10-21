#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';
use KinoSearch::Store::RAMInvIndex;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

for my $num_fields ( 1 .. 10 ) {
    # build an invindex with $num_fields fields, and the same content in each
    my $invindex = KinoSearch::Store::RAMInvIndex->new( create => 1 );
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $invindex,
        analyzer => $tokenizer,
    );
    for my $field_name ( 1 .. $num_fields ) {
        $invindexer->spec_field( name => $field_name );
    }
    for my $content ( 'a' .. 'z', 'x x y' ) {
        my $doc = $invindexer->new_doc;
        for my $field_name ( 1 .. $num_fields ) {
            $doc->set_value( $field_name => $content );
        }
        $invindexer->add_doc($doc);
    }
    $invindexer->finish;

    # see if our search results match as expected.
    my $searcher = KinoSearch::Searcher->new(
        invindex => $invindex,
        analyzer => $tokenizer,
    );
    my $hits = $searcher->search('x');
    $hits->seek( 0, 100 );
    is( $hits->total_hits, 2,
        "correct number of hits for $num_fields fields" );
    my $top_hit = $hits->fetch_hit_hashref;
}
