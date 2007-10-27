use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 5;

BEGIN {
    use_ok('KinoSearch::Search::RemoteFieldDoc');
}

use KinoSearch::Util::VArray;
use KinoSearch::Util::ByteBuf;
use KinoSearch::Util::Native qw( to_perl );
use Storable qw( freeze thaw );

my $field_vals = KinoSearch::Util::VArray->new( capacity => 4 );
$field_vals->store( 0, KinoSearch::Util::ByteBuf->new("foo") );
$field_vals->store( 3, KinoSearch::Util::ByteBuf->new("bar") );
my $remote_doc = KinoSearch::Search::RemoteFieldDoc->new(
    doc_num    => 120,
    score      => 35,
    field_vals => $field_vals,
);
is( $remote_doc->get_doc_num => 120, "RemoteFieldDoc get_doc_num" );
my $remote_doc_copy = thaw( freeze($remote_doc) );
is( $remote_doc_copy->get_doc_num => 120,
    "RemoteFieldDoc doc_num survives serialization"
);
is( $remote_doc_copy->get_score => 35,
    "RemoteFieldDoc score survives serialization"
);
my $vals_copy = to_perl( $remote_doc_copy->get_field_vals );
is_deeply(
    $vals_copy,
    [ 'foo', undef, undef, 'bar' ],
    "field_vals survives serialization"
);

