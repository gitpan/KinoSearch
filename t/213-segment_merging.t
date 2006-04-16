use strict;
use warnings;

use lib 't';
use Test::More tests => 8;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::InvIndexer');
    use_ok('KinoSearch::Searcher');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Store::RAMInvIndex');
}

use KinoSearchTestInvIndex qw( create_invindex );

my ( $invindexer, $searcher, $hits, $another_invindex,
    $yet_another_invindex );
my $invindex  = KinoSearch::Store::RAMInvIndex->new();
my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

for my $iter ( 1 .. 10 ) {
    $invindexer = KinoSearch::InvIndexer->new(
        create => $iter == 1 ? 1 : 0,
        invindex => $invindex,
        analyzer => $tokenizer,
    );
    $invindexer->spec_field( name => 'letters' );

    for my $letter ( 'a' .. 'b' ) {
        my $doc     = $invindexer->new_doc;
        my $content = ( "$letter " x $iter ) . 'z';

        $doc->set_value( letters => $content );
        $invindexer->add_doc($doc);
    }
    $invindexer->finish;
}

$searcher = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => $tokenizer,
);
$hits = $searcher->search( query => 'b' );
is( $hits->total_hits, 10, "correct total_hits from merged invindex" );
is( $hits->fetch_hit_hashref->{letters},
    "b b b b b b b b b b z",
    "correct top scoring hit from merged invindex"
);

$invindexer = KinoSearch::InvIndexer->new(
    invindex => $invindex,
    analyzer => $tokenizer,
);
$another_invindex = create_invindex( "atlantic ocean", "fresh fish" );
$yet_another_invindex = create_invindex("bonus");
$invindexer->add_invindexes( $another_invindex, $yet_another_invindex );
$invindexer->finish;
$searcher = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => $tokenizer,
);
$hits = $searcher->search( query => 'fish' );
is( $hits->total_hits, 1, "correct total_hits after add_invindexes" );
is( $hits->fetch_hit_hashref->{content},
    'fresh fish', "other invindexes successfully absorbed" );

