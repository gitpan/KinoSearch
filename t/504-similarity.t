use strict;
use warnings;

package MySchema::LongTextField;
use base qw( KinoSearch::Plan::FullTextType );
use KSx::Index::LongFieldSim;

sub make_similarity { KSx::Index::LongFieldSim->new }

package MySchema;
use base qw( KinoSearch::Plan::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $self     = shift->SUPER::new(@_);
    my $analyzer = KinoSearch::Analysis::Tokenizer->new;
    my $plain_type
        = KinoSearch::Plan::FullTextType->new( analyzer => $analyzer, );
    my $long_field_type
        = MySchema::LongTextField->new( analyzer => $analyzer, );
    $self->spec_field( name => 'title', type => $plain_type );
    $self->spec_field( name => 'body',  type => $long_field_type );
    return $self;
}

package main;
use Test::More tests => 9;
use KinoSearch::Test;
use bytes;
no bytes;

my $sim       = KinoSearch::Index::Similarity->new;
my $evil_twin = $sim->load( $sim->dump );
ok( $sim->equals($evil_twin), "Dump/Load" );

cmp_ok( $sim->tf(10) - $sim->tf(9), '<', 1, "TF is damped" );

my $rare_idf   = $sim->idf( doc_freq => 3,  total_docs => 100 );
my $common_idf = $sim->idf( doc_freq => 50, total_docs => 100 );
cmp_ok( $rare_idf, '>', $common_idf, 'Rarer terms have higher IDF' );

my $less_coordinated = $sim->coord( overlap => 2, max_overlap => 5 );
my $more_coordinated = $sim->coord( overlap => 3, max_overlap => 5 );
cmp_ok( $less_coordinated, '<', $more_coordinated,
    "greater overlap means bigger coord bonus" );

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

my $folder  = KinoSearch::Store::RAMFolder->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => MySchema->new,
);

my %source_docs = (
    'spam'     => 'spam spam',
    'not spam' => 'not spam not even close to spam no spam here',
);
while ( my ( $title, $body ) = each %source_docs ) {
    $indexer->add_doc(
        {   title => $title,
            body  => $body,
        }
    );
}
$indexer->commit;
undef $indexer;

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $hits = $searcher->hits(
    query => KinoSearch::Search::TermQuery->new(
        field => 'title',
        term  => 'spam',
    )
);
is( $hits->next->{'title'},
    'spam', "Default Similarity biased towards short fields" );

$hits = $searcher->hits(
    query => KinoSearch::Search::TermQuery->new(
        field => 'body',
        term  => 'spam',
    )
);
is( $hits->next->{'title'},
    'not spam', "LongFieldSim cancels short-field bias" );
