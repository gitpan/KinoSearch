use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 5;
use KinoSearch::Test;
use KinoSearch::Util::ToolSet qw( to_perl );

my $letters = KinoSearch::Obj::VArray->new( capacity => 26 );
$letters->push( KinoSearch::Obj::ByteBuf->new($_) ) for 'a' .. 'z';
my $run = KinoSearch::Test::Util::BBSortExRun->new( external => $letters );
$run->set_mem_thresh(5);

my $num_in_cache = $run->refill;
is( $run->cache_count, 5, "Read_Elem puts the brakes on Refill" );
my $endpost = $run->peek_last;
is( $endpost, 'e', "Peek_Last" );
$endpost = KinoSearch::Obj::ByteBuf->new('b');
my $slice = $run->pop_slice($endpost);
is( scalar @$slice, 2, "Pop_Slice gets only less-than-or-equal elems" );
@$slice = map { to_perl($_) } @$slice;
is_deeply( $slice, [qw( a b )], "Pop_Slice picks highest elems" );

my @got = qw( a b );
while (1) {
    $endpost = $run->peek_last;
    $slice   = $run->pop_slice( KinoSearch::Obj::ByteBuf->new($endpost) );
    push @got, map { to_perl($_) } @$slice;
    last unless $run->refill;
}
is_deeply( \@got, [ 'a' .. 'z' ], "retrieve all elems" );

