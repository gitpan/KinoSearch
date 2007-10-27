use strict;
use warnings;
use lib 'buildlib';

use KinoTestUtils qw( create_invindex );
use Test::More tests => 1;

use KinoSearch::Searcher;

my $good     = "x a x x x x b x x x x c x";
my $better   = "x x x x a x b x c x x x x";
my $best     = "x x x x x a b c x x x x x";
my $invindex = create_invindex( $good, $better, $best );

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $hits = $searcher->search( query => 'a b c' );

my @contents;
while ( my $hit = $hits->fetch_hit_hashref ) {
    push @contents, $hit->{content};
}

TODO: {
    local $TODO = "positions not passed to boolscorer correctly yet";
    is_deeply(
        \@contents,
        [ $best, $better, $good ],
        "proximity helps boost scores"
    );
}

