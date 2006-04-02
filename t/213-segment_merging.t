use strict;
use warnings;

use Test::More tests => 6;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::InvIndexer');
    use_ok('KinoSearch::Searcher');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Store::RAMInvIndex');
}

my $invindex  = KinoSearch::Store::RAMInvIndex->new();
my $tokenizer = KinoSearch::Analysis::Tokenizer->new;
for my $iter ( 1 .. 10 ) {
    my $invindexer = KinoSearch::InvIndexer->new(
        create => $iter == 1 ? 1 : 0,
        invindex => $invindex,
        analyzer => $tokenizer,
    );
    $invindexer->spec_field( name => 'content' );

    for my $letter ( 'a' .. 'b' ) {
        my $doc     = $invindexer->new_doc;
        my $content = ( "$letter " x $iter ) . 'z';

        $doc->set_value( content => $content );
        $invindexer->add_doc($doc);
    }
    $invindexer->finish;
}

my $searcher = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => $tokenizer,
);
my $hits = $searcher->search('b');
is( $hits->total_hits, 10, "correct total_hits from merged invindex" );
is( $hits->fetch_hit_hashref->{content},
    "b b b b b b b b b b z",
    "correct top scoring hit from merged invindex"
);

