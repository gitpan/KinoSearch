use strict;
use warnings;

use lib 'buildlib';
use KinoSearch::Test;

package ControlSchema;
use base qw( KinoSearch::Plan::Schema );

sub new {
    my $self = shift->SUPER::new(@_);
    my $type = KinoSearch::Plan::FullTextType->new(
        analyzer => KinoSearch::Analysis::Tokenizer->new );
    $self->spec_field( name => 'content',  type => $type );
    $self->spec_field( name => 'category', type => $type );
    return $self;
}

package BoostedFieldSchema;
use base qw( KinoSearch::Plan::Schema );

sub new {
    my $self      = shift->SUPER::new(@_);
    my $tokenizer = KinoSearch::Analysis::Tokenizer->new;
    my $plain_type
        = KinoSearch::Plan::FullTextType->new( analyzer => $tokenizer );
    my $boosted_type = KinoSearch::Plan::FullTextType->new(
        analyzer => $tokenizer,
        boost    => 100,
    );
    $self->spec_field( name => 'content',  type => $plain_type );
    $self->spec_field( name => 'category', type => $boosted_type );
    return $self;
}

package main;
use Test::More tests => 3;

my $control_folder       = KinoSearch::Store::RAMFolder->new;
my $boosted_doc_folder   = KinoSearch::Store::RAMFolder->new;
my $boosted_field_folder = KinoSearch::Store::RAMFolder->new;
my $control_indexer      = KinoSearch::Index::Indexer->new(
    schema => ControlSchema->new,
    index  => $control_folder,
);
my $boosted_field_indexer = KinoSearch::Index::Indexer->new(
    schema => BoostedFieldSchema->new,
    index  => $boosted_field_folder,
);
my $boosted_doc_indexer = KinoSearch::Index::Indexer->new(
    schema => ControlSchema->new,
    index  => $boosted_doc_folder,
);

my %source_docs = (
    'x'         => '',
    'x a a a a' => 'x a',
    'a b'       => 'x a a',
);

while ( my ( $content, $cat ) = each %source_docs ) {
    my %fields = (
        content  => $content,
        category => $cat,
    );
    $control_indexer->add_doc( \%fields );
    $boosted_field_indexer->add_doc( \%fields );

    my $boost = $content =~ /b/ ? 2 : 1;
    $boosted_doc_indexer->add_doc( doc => \%fields, boost => $boost );
}

$control_indexer->commit;
$boosted_field_indexer->commit;
$boosted_doc_indexer->commit;

my $searcher
    = KinoSearch::Search::IndexSearcher->new( index => $control_folder, );
my $hits = $searcher->hits( query => 'a' );
my $hit = $hits->next;
is( $hit->{content}, "x a a a a", "best doc ranks highest with no boosting" );

$searcher
    = KinoSearch::Search::IndexSearcher->new( index => $boosted_field_folder,
    );
$hits = $searcher->hits( query => 'a' );
$hit = $hits->next;
is( $hit->{content}, 'a b', "boost in FieldType works" );

$searcher
    = KinoSearch::Search::IndexSearcher->new( index => $boosted_doc_folder, );
$hits = $searcher->hits( query => 'a' );
$hit = $hits->next;
is( $hit->{content}, 'a b', "boost from \$doc->set_boost works" );
