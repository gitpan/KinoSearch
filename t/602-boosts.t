use strict;
use warnings;
use lib 'buildlib';

package ControlSchema::content;
use base qw( KinoSearch::Schema::FieldSpec );

package ControlSchema::category;
use base qw( KinoSearch::Schema::FieldSpec );

package ControlSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }
__PACKAGE__->init_fields(qw( content category ));

package BoostedFieldSchema::content;
use base qw( KinoSearch::Schema::FieldSpec );

package BoostedFieldSchema::category;
use base qw( KinoSearch::Schema::FieldSpec );
sub boost {100}

package BoostedFieldSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }
__PACKAGE__->init_fields(qw( content category ));

package main;

use Test::More tests => 3;

use KinoSearch::Store::RAMFolder;
use KinoSearch::Searcher;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;

my $control_folder       = KinoSearch::Store::RAMFolder->new;
my $boosted_doc_folder   = KinoSearch::Store::RAMFolder->new;
my $boosted_field_folder = KinoSearch::Store::RAMFolder->new;
my $control_invindex     = KinoSearch::InvIndex->create(
    schema => ControlSchema->new,
    folder => $control_folder,
);
my $boosted_field_invindex = KinoSearch::InvIndex->create(
    schema => BoostedFieldSchema->new,
    folder => $boosted_field_folder,
);
my $boosted_doc_invindex = KinoSearch::InvIndex->create(
    schema => ControlSchema->new,
    folder => $boosted_doc_folder,
);

my $control_invindexer
    = KinoSearch::InvIndexer->new( invindex => $control_invindex, );
my $boosted_field_invindexer
    = KinoSearch::InvIndexer->new( invindex => $boosted_field_invindex, );
my $boosted_doc_invindexer
    = KinoSearch::InvIndexer->new( invindex => $boosted_doc_invindex, );

my %source_docs = (
    'x'         => '',
    'x a a a a' => 'x a',
    'a b'       => 'x a a',
);

while ( my ( $content, $cat ) = each %source_docs ) {
    my %doc = (
        content  => $content,
        category => $cat
    );
    $control_invindexer->add_doc( \%doc );
    $boosted_field_invindexer->add_doc( \%doc );

    my $boost = $content =~ /b/ ? 2 : 1;
    $boosted_doc_invindexer->add_doc( \%doc, boost => $boost );
}

$control_invindexer->finish;
$boosted_field_invindexer->finish;
$boosted_doc_invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $control_invindex, );
my $hits     = $searcher->search( query            => 'a' );
$hits->seek( 0, 1 );
my $hit = $hits->fetch_hit_hashref;
is( $hit->{content}, "x a a a a", "best doc ranks highest with no boosting" );

$searcher = KinoSearch::Searcher->new( invindex => $boosted_field_invindex, );
$hits     = $searcher->search( query            => 'a' );
$hits->seek( 0, 3 );
$hit = $hits->fetch_hit_hashref;
is( $hit->{content}, 'a b', "boost in Field spec works" );

$searcher = KinoSearch::Searcher->new( invindex => $boosted_doc_invindex, );
$hits     = $searcher->search( query            => 'a' );
$hits->seek( 0, 3 );
$hit = $hits->fetch_hit_hashref;
is( $hit->{content}, 'a b', "boost from \$doc->set_boost works" );
