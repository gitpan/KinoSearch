use strict;
use warnings;

package MySchema::LongField;
use base qw( KinoSearch::Schema::FieldSpec );
use KSx::Search::LongFieldSim;
sub similarity { KSx::Search::LongFieldSim->new }

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    title => 'KinoSearch::Schema::FieldSpec',
    body  => 'MySchema::LongField',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 5;

use KinoSearch::Search::Similarity;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;

my $sim = KinoSearch::Search::Similarity->new;

my @bytes  = ( 100,      110,     120, 130, 140 );
my @floats = ( 0.015625, 0.09375, 0.5, 3.0, 16.0 );
my @transformed = map { $sim->decode_norm($_) } @bytes;
is_deeply( \@floats, \@transformed,
    "decode_norm more or less matches Java Lucene behavior" );

@bytes       = 0 .. 255;
@floats      = map { $sim->decode_norm($_) } @bytes;
@transformed = map { $sim->encode_norm($_) } @floats;
is_deeply( \@transformed, \@bytes,
    "encode_norm and decode_norm are complementary" );

my $norm_decoder = $sim->get_norm_decoder;
@transformed = ();
for ( 0 .. 255 ) {
    push @transformed,
        unpack( 'f', bytes::substr( $norm_decoder, $_ * 4, 4 ) );
}
is_deeply( \@transformed, \@floats,
    "using the norm_decoder produces desired results" );

my $folder   = KinoSearch::Store::RAMFolder->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => MySchema->new,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

my %source_docs = (
    'spam'     => 'spam spam',
    'not spam' => 'not spam not even close to spam no spam here',
);
while ( my ( $title, $body ) = each %source_docs ) {
    $invindexer->add_doc(
        {   title => $title,
            body  => $body,
        }
    );
}
$invindexer->finish;
undef $invindexer;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $hits = $searcher->search(
    query => KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'title', 'spam' )
    )
);
is( $hits->fetch_hit_hashref->{'title'},
    'spam', "Default Similarity biased towards short fields" );

$hits = $searcher->search(
    query => KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'body', 'spam' )
    )
);
is( $hits->fetch_hit_hashref->{'title'},
    'not spam', "LongFieldSim cancels short-field bias" );

