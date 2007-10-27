use strict;
use warnings;

use lib 't';
use Test::More tests => 11;

BEGIN { use_ok('KinoSearch::Index::DelDocs') }
use KinoSearchTestInvIndex qw( create_invindex );

my $invindex = create_invindex( 'a' .. 'e' );

my $deldocs = KinoSearch::Index::DelDocs->new();

$deldocs->read_deldocs( $invindex, "_1.del" );
$deldocs->set(3);
$deldocs->set(3);

my @deleted_or_not = map { $deldocs->get($_) } 0 .. 4;
is_deeply( \@deleted_or_not, [ '', '', '', 1, '' ], "set works" );
is( $deldocs->get_num_deletions, 1, "set increments num_deletions, once" );

my $doc_map = $deldocs->generate_doc_map( 5, 0 );
my $correct_doc_map = pack( 'i*', 0, 1, 2, -1, 3 );
is( $$doc_map, $correct_doc_map, "doc map maps around deleted docs" );
$doc_map = $deldocs->generate_doc_map( 5, 100 );
is( $doc_map->get(4), 103,   "doc map handles offset correctly" );
is( $doc_map->get(3), undef, "doc_map handled deletions correctly" );
is( $doc_map->get(6), undef, "doc_map returns undef for out of range" );

$deldocs->clear(3);
$deldocs->clear(3);
$deldocs->clear(3);
is( $deldocs->get_num_deletions, 0, "clear decrements num_deletions, once" );

$deldocs->set(2);
$deldocs->set(1);
$deldocs->write_deldocs( $invindex, "_1.del", 8 );
$deldocs = KinoSearch::Index::DelDocs->new();
$deldocs->read_deldocs( $invindex, "_1.del" );

@deleted_or_not = map { $deldocs->get($_) } 0 .. 7;
is_deeply(
    \@deleted_or_not,
    [ '', 1, 1, '', '', '', '', '' ],
    "write_deldocs and read_deldocs save/recover deletions correctly"
);

is( $deldocs->get_num_deletions, 2,
    "write_deldocs and read_deldocs save/recover num_deletions correctly" );
is( $deldocs->get_capacity, 8,
    "write_deldocs wrote correct number of bytes" );
