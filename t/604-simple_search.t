use strict;
use warnings;

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    title => 'KinoSearch::Schema::FieldSpec',
    body  => 'KinoSearch::Schema::FieldSpec',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use Test::More tests => 12;

use KinoSearch::Searcher;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;
use KinoSearch::QueryParser;
use KinoSearch::Analysis::Tokenizer;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
my %docs = (
    'a' => 'foo',
    'b' => 'bar',
);
while ( my ( $title, $body ) = each %docs ) {
    $invindexer->add_doc(
        {   title => $title,
            body  => $body,
        }
    );
}
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;
my $or_parser = KinoSearch::QueryParser->new(
    schema   => $schema,
    analyzer => $tokenizer,
    fields   => [ 'title', 'body', ],
);
my $and_parser = KinoSearch::QueryParser->new(
    schema         => $schema,
    analyzer       => $tokenizer,
    fields         => [ 'title', 'body', ],
    default_boolop => 'AND',
);

sub test_qstring {
    my ( $qstring, $expected, $message ) = @_;

    my $hits = $searcher->search( query => $qstring );
    is( $hits->total_hits, $expected, $message );

    my $query = $or_parser->parse($qstring);
    $hits = $searcher->search( query => $query );
    is( $hits->total_hits, $expected, "OR: $message" );

    $query = $and_parser->parse($qstring);
    $hits = $searcher->search( query => $query );
    is( $hits->total_hits, $expected, "AND: $message" );
}

test_qstring( 'a foo', 1, "simple match across multiple fields" );
test_qstring( 'a -foo', 0,
    "match of negated term on any field should exclude document" );
test_qstring(
    'a +foo',
    1,
    "failure to match of required term on a field "
        . "should not exclude doc if another field matches."
);
test_qstring( '+a +foo', 1,
    "required terms spread across disparate fields should match" );
