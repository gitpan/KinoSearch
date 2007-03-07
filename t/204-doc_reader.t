use strict;
use warnings;

use Test::More tests => 9;

BEGIN { use_ok('KinoSearch::InvIndexer') }
BEGIN { use_ok('KinoSearch::Store::RAMFolder') }
BEGIN { use_ok('KinoSearch::Index::DocReader') }
BEGIN { use_ok('KinoSearch::Index::CompoundFileReader') }

package MySchema::textcomp;
use base qw( KinoSearch::Schema::FieldSpec );

sub compressed {1}

package MySchema::bin;
use base qw( KinoSearch::Schema::FieldSpec );

sub binary {1}

package MySchema::bincomp;
use base qw( KinoSearch::Schema::FieldSpec );

sub binary     {1}
sub compressed {1}

package MySchema::unstored;
use base qw( KinoSearch::Schema::FieldSpec );

sub stored {0}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Analyzer;

our %FIELDS = (
    text     => 'KinoSearch::Schema::FieldSpec',
    textcomp => 'MySchema::textcomp',
    bin      => 'MySchema::bin',
    bincomp  => 'MySchema::bincomp',
    unstored => 'MySchema::unstored',
);

sub analyzer { KinoSearch::Analysis::Analyzer->new }

package main;
use Encode qw( _utf8_on );

# This valid UTF-8 string includes skull and crossbones, null byte -- however,
# the binary value is not flagged as UTF-8.
my $bin_val = my $val = "a b c \xe2\x98\xA0 \0a";
_utf8_on($val);

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
$invindexer->add_doc(
    {   text     => $val,
        textcomp => $val,
        bin      => $bin_val,
        bincomp  => $bin_val,
        unstored => $val,
    }
);
$invindexer->finish;

my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos($folder);
my $seg_info = $seg_infos->get_info('_1');

my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my $doc_reader = KinoSearch::Index::DocReader->new(
    folder   => $cf_reader,
    schema   => $invindex->get_schema,
    seg_info => $seg_info,
);

my $doc = $doc_reader->fetch_doc(0);

is( $doc->{text},     $val,     "text" );
is( $doc->{textcomp}, $val,     "textcomp" );
is( $doc->{bin},      $bin_val, "bin" );
is( $doc->{bincomp},  $bin_val, "bincomp" );
is( $doc->{unstored}, undef,    "unstored" );
