use strict;
use warnings;
use lib 'buildlib';

use TestSchema;
use Test::More tests => 9;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;

my $schema   = TestSchema->new;
my $folder   = KinoSearch::Store::RAMFolder->new;
my $invindex = KinoSearch::InvIndex->create(
    schema => $schema,
    folder => $folder,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

my %one_field = ( content => 'x 1' );
my %two_fields   = ( content => 'x x 2',   a   => 'a' );
my %three_fields = ( content => 'x x x 3', a   => 'a', b => 'b' );
my %four_fields  = ( content => 'x x x 3', a   => 'a', b => 'b', c => 'c', );
my %foo_doc      = ( content => 'foo',     foo => 'foo' );
my %five_fields = (
    content => 'x x x x x 5',
    a       => 'a',
    b       => 'b',
    c       => 'c',
    foo     => 'stuff'
);

$invindexer->add_doc( \%one_field );
$schema->add_field( a => 'KinoSearch::Schema::FieldSpec' );
$invindexer->add_doc( \%two_fields );
pass('Add a field in the middle of indexing');

$schema->add_field( a => 'KinoSearch::Schema::FieldSpec' );
pass('Add same field again');

$schema->add_field( b => 'KinoSearch::Schema::FieldSpec' );
$invindexer->add_doc( \%three_fields );
pass('Add another field');
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );
my $hits = $searcher->search( query => 'x', num_wanted => 100 );
is( $hits->total_hits, 3,
    "disparate docs successfully indexed and retrieved" );
my $top_hit = $hits->fetch_hit_hashref;
delete $top_hit->{score};
is_deeply( $top_hit, \%three_fields, "all fields stored successfully" );

my $schema2   = TestSchema->new;
my $folder2   = KinoSearch::Store::RAMFolder->new;
my $invindex2 = KinoSearch::InvIndex->create(
    schema => $schema2,
    folder => $folder2,
);

$schema2->add_field( foo => 'KinoSearch::Schema::FieldSpec' );
my $invindexer2 = KinoSearch::InvIndexer->new( invindex => $invindex2 );
$invindexer2->add_doc( \%foo_doc );
$invindexer2->finish;

undef $invindexer;
$invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

$schema->add_field( c => 'KinoSearch::Schema::FieldSpec' );
$invindexer->add_doc( \%four_fields );

$invindexer->add_invindexes($invindex2);
$invindexer->add_doc( \%five_fields );
pass('successfully absorbed new field def during add_invindexes');
$invindexer->finish;

$searcher = KinoSearch::Searcher->new( invindex => $invindex, );
$hits = $searcher->search( query => 'stuff', num_wanted => 100 );
is( $hits->total_hits, 1,
    "successfully aborbed unknown field during add_invindexes" );
$top_hit = $hits->fetch_hit_hashref;
delete $top_hit->{score};
is_deeply( $top_hit, \%five_fields, "all fields stored successfully" );

$hits = $searcher->search( query => 'x', num_wanted => 100 );
is( $hits->total_hits, 5, "indexes successfully merged" );

