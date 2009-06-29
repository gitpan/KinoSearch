use strict;
use warnings;

use Test::More tests => 5;

package TestAnalyzer;
use base qw( KinoSearch::Analysis::Analyzer );
sub transform { $_[1] }

package main;
use Encode qw( _utf8_on );

sub new_schema {
    my $schema   = KinoSearch::Schema->new;
    my $analyzer = TestAnalyzer->new;
    my $fulltext
        = KinoSearch::FieldType::FullTextType->new( analyzer => $analyzer );
    my $bin        = KinoSearch::FieldType::BlobType->new;
    my $not_stored = KinoSearch::FieldType::FullTextType->new(
        analyzer => $analyzer,
        stored   => 0,
    );
    my $float64 = KinoSearch::FieldType::Float64Type->new( indexed => 0 );
    $schema->spec_field( name => 'text',     type => $fulltext );
    $schema->spec_field( name => 'bin',      type => $bin );
    $schema->spec_field( name => 'unstored', type => $not_stored );
    $schema->spec_field( name => 'float64',  type => $float64 );
    $schema->spec_field( name => 'empty',    type => $fulltext );
    return $schema;
}

# This valid UTF-8 string includes skull and crossbones, null byte -- however,
# the binary value is not flagged as UTF-8.
my $bin_val = my $val = "a b c \xe2\x98\xA0 \0a";
_utf8_on($val);

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = new_schema();

my $indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
    create => 1,
);
$indexer->add_doc(
    {   text     => $val,
        bin      => $bin_val,
        unstored => $val,
        empty    => '',
        float64  => 2.0,
    }
);
$indexer->commit;

my $snapshot
    = KinoSearch::Index::Snapshot->new->read_file( folder => $folder );
my $segment = KinoSearch::Index::Segment->new(
    folder => $folder,
    name   => 'seg_1'
);
$segment->read_file;
my $doc_reader = KinoSearch::Index::DefaultDocReader->new(
    schema   => $schema,
    folder   => $folder,
    snapshot => $snapshot,
    segments => [$segment],
    seg_tick => 0,
);

my $doc = $doc_reader->fetch( doc_id => 0 );

is( $doc->{text},     $val,     "text" );
is( $doc->{bin},      $bin_val, "bin" );
is( $doc->{unstored}, undef,    "unstored" );
is( $doc->{empty},    '',       "empty" );
is( $doc->{float64},  2.0,      "float64" );
