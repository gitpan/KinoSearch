use strict;
use warnings;
use lib 'buildlib';

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'KinoSearch::Schema::FieldSpec' );

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package AltSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    content => 'KinoSearch::Schema::FieldSpec',
    aux     => 'KinoSearch::Schema::FieldSpec',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use utf8;
use Test::More tests => 4;

use KinoSearch::Index::DocVector;
use KinoSearch::Index::TermVector;
use KinoSearch::Searcher;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;

my $schema   = MySchema->new;
my $folder   = KinoSearch::Store::RAMFolder->new;
my $invindex = KinoSearch::InvIndex->clobber(
    schema => $schema,
    folder => $folder,
);

my $hasta = 'hasta la mañana';
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
for ( 'a b c foo foo bar', $hasta ) {
    $invindexer->add_doc( { content => $_ } );
}
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );
my $doc_vec = $searcher->fetch_doc_vec(0);

my $term_vector = $doc_vec->term_vector( "content", "foo" );
ok( defined $term_vector, "successfully retrieved term vector" );

$doc_vec = $searcher->fetch_doc_vec(1);
$term_vector = $doc_vec->term_vector( 'content', 'mañana' );

ok( defined $term_vector, "utf-8 term vector retrieved" );
is( $term_vector->{end_offsets}[0],
    length $hasta,
    "end offset in utf8 characters, not bytes"
);

# Reopen the Folder under a new Schema with two fields.  The new field ("aux")
# sorts lexically before "content" so that "content" will have a new field
# num.  This tests the field num mapping during merging.
my $alt_schema = AltSchema->new;
my $reopened   = KinoSearch::InvIndex->open(
    folder => $folder,
    schema => $alt_schema,
);

my $alt_folder   = KinoSearch::Store::RAMFolder->new;
my $alt_invindex = KinoSearch::InvIndex->clobber(
    schema => $alt_schema,
    folder => $alt_folder,
);

$invindexer = KinoSearch::InvIndexer->new( invindex => $alt_invindex );
for ( 'blah blah blah ', 'yada yada yada ' ) {
    $invindexer->add_doc(
        {   content => $_,
            aux     => $_ . $_,
        }
    );
}
$invindexer->finish;

$invindexer = KinoSearch::InvIndexer->new( invindex => $alt_invindex );
$invindexer->add_invindexes($reopened);
$invindexer->finish;

$searcher = KinoSearch::Searcher->new( invindex => $alt_invindex );
my $hits = $searcher->search( query => $hasta );
my $hit_id = $hits->{score_docs}[0]->get_doc_num;
$doc_vec = $searcher->fetch_doc_vec($hit_id);
$term_vector = $doc_vec->term_vector( 'content', 'mañana' );
ok( defined $term_vector, "utf-8 term vector retrieved after merge" );
