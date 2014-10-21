use strict;
use warnings;

use lib 'buildlib';
use KinoSearch::Test;

package MySchema;
use base qw( KinoSearch::Plan::Schema );

sub new {
    my $self = shift->SUPER::new(@_);
    my $type = KinoSearch::Plan::FullTextType->new(
        analyzer      => KinoSearch::Analysis::Tokenizer->new,
        highlightable => 1,
    );
    $self->spec_field( name => 'content', type => $type );
    return $self;
}

package main;
use utf8;
use Test::More tests => 5;
use Storable qw( freeze thaw );

my $schema  = MySchema->new;
my $folder  = KinoSearch::Store::RAMFolder->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);

my $hasta = 'hasta la mañana';
for ( 'a b c foo foo bar', $hasta ) {
    $indexer->add_doc( { content => $_ } );
}
$indexer->commit;

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
my $doc_vec = $searcher->fetch_doc_vec(1);

my $term_vector = $doc_vec->term_vector( field => "content", term => "foo" );
ok( defined $term_vector, "successfully retrieved term vector" );

$doc_vec = $searcher->fetch_doc_vec(2);
$term_vector = $doc_vec->term_vector( field => 'content', term => 'mañana' );

ok( defined $term_vector, "utf-8 term vector retrieved" );
is( $term_vector->get_end_offsets->get(0),
    length $hasta,
    "end offset in utf8 characters, not bytes"
);

# Reopen the Folder under a new Schema with two fields.  The new field ("aux")
# sorts lexically before "content" so that "content" will have a new field
# num.  This tests the field num mapping during merging.
my $alt_folder = KinoSearch::Store::RAMFolder->new;
my $alt_schema = MySchema->new;
my $type       = $alt_schema->fetch_type('content');
$alt_schema->spec_field( name => 'aux', type => $type );

$indexer = KinoSearch::Index::Indexer->new(
    schema => $alt_schema,
    index  => $alt_folder,
);
for ( 'blah blah blah ', 'yada yada yada ' ) {
    $indexer->add_doc(
        {   content => $_,
            aux     => $_ . $_,
        }
    );
}
$indexer->commit;

$indexer = KinoSearch::Index::Indexer->new(
    schema => $alt_schema,
    index  => $alt_folder,
);
$indexer->add_index($folder);
$indexer->commit;

$searcher = KinoSearch::Search::IndexSearcher->new( index => $alt_folder );
my $hits = $searcher->hits( query => $hasta );
my $hit_id = $hits->next->get_doc_id;
$doc_vec = $searcher->fetch_doc_vec($hit_id);
$term_vector = $doc_vec->term_vector( field => 'content', term => 'mañana' );
ok( defined $term_vector, "utf-8 term vector retrieved after merge" );

my $dupe = thaw( freeze($term_vector) );
ok( $term_vector->equals($dupe), "freeze/thaw" );
