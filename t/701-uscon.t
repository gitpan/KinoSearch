use strict;
use warnings;

use Test::More tests => 10;
use File::Spec::Functions qw( catfile );
use Carp;

BEGIN {
    use_ok('KinoSearch::Searcher');
    use_ok('KinoSearch::Analysis::PolyAnalyzer');
}
my $tokenizer = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
my $searcher = KinoSearch::Searcher->new(
    invindex => 'test_invindex',
    analyzer => $tokenizer,
);

my %searches = (
    'United'              => 34,
    'shall'               => 50,
    'not'                 => 27,
    '"shall not"'         => 21,
    'shall not'           => 51,
    'Congress'            => 31,
    'Congress AND United' => 22,
    '(Congress AND United) OR ((Vice AND President) OR "free exercise")' =>
        28,
);

while ( my ( $qstring, $num_expected ) = each %searches ) {
    my $hits = $searcher->search($qstring);
    $hits->seek( 0, 100 );
    is( $hits->total_hits, $num_expected, $qstring );
}

