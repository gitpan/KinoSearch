use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

package MySchema::UnAnalyzed;
use base qw( KinoSearch::FieldSpec::text );
sub analyzed {0}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    name   => 'text',
    number => 'MySchema::UnAnalyzed',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use KinoSearch::Search::MatchFieldQuery;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;

my $invindex = KinoSearch::InvIndex->clobber(
    schema => MySchema->new,
    folder => KinoSearch::Store::RAMFolder->new,
);
my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );

$invindexer->add_doc( { name => 'foo', number => $_ } )
    for ( reverse 0 .. 2 );
$invindexer->add_doc( { name => 'bar' } );
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $query = KinoSearch::Search::MatchFieldQuery->new( field => 'number' );
my $hits = $searcher->search( query => $query );
is( $hits->total_hits, 3, "correct number of hits" );

my @got;
while ( my $hit = $hits->fetch_hit_hashref ) {
    push @got, $hit->{number};
}
is_deeply( [ sort @got ], [ 0 .. 2 ], "Correct docs included/excluded" );

$query = KinoSearch::Search::MatchFieldQuery->new( field => 'not_there' );
$hits = $searcher->search( query => $query );
is( $hits->total_hits, 0, "non-existent field produces no hits" );

$query = KinoSearch::Search::MatchFieldQuery->new( field => 'name' );
$hits = $searcher->search( query => $query );
# this probably isn't the best behavior
is( $hits->total_hits, 0, "non-tokenized field produces no hits" );

