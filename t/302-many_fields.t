use strict;
use warnings;

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 10;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;

for my $num_fields ( 1 .. 10 ) {
    # build an invindex with $num_fields fields, and the same content in each
    my $field_name = "field$num_fields";
    eval qq|package MySchema::$field_name;
            use base qw( KinoSearch::Schema::FieldSpec );
            MySchema->init_fields(qw( $field_name ));
            package main;
            |;
    die $@ if $@;
    my $folder   = KinoSearch::Store::RAMFolder->new;
    my $invindex = KinoSearch::InvIndex->create(
        schema => MySchema->new,
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
    my $hits     = $searcher->search( query            => 'x' );
    $hits->seek( 0, 100 );
    is( $hits->total_hits, 2,
        "correct number of hits for $num_fields fields" );
    my $top_hit = $hits->fetch_hit_hashref;
}
