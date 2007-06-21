use strict;
use warnings;

use Test::More tests => 9;

use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::TokenBatch;

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

my ($text) = $tokenizer->analyze_raw("o'malley's");
is( $text, "o'malley's", "multiple apostrophes for default token_re" );

my $batch = KinoSearch::Analysis::TokenBatch->new( text => "a b c" );
$batch = $tokenizer->analyze_batch($batch);

my ( @token_texts, @start_offsets, @end_offsets );
while ( my $token = $batch->next ) {
    push @token_texts,   $token->get_text;
    push @start_offsets, $token->get_start_offset;
    push @end_offsets,   $token->get_end_offset;
}
is_deeply( \@token_texts, [qw( a b c )], "correct texts" );
is_deeply( \@start_offsets, [ 0, 2, 4, ], "correctstart offsets" );
is_deeply( \@end_offsets,   [ 1, 3, 5, ], "correct end offsets" );

$tokenizer = KinoSearch::Analysis::Tokenizer->new( token_re => qr/./ );
$batch     = KinoSearch::Analysis::TokenBatch->new( text    => "a b c" );
$batch     = $tokenizer->analyze_batch($batch);

@token_texts   = ();
@start_offsets = ();
@end_offsets   = ();
while ( my $token = $batch->next ) {
    push @token_texts,   $token->get_text;
    push @start_offsets, $token->get_start_offset;
    push @end_offsets,   $token->get_end_offset;
}
is_deeply( \@token_texts, [ 'a', ' ', 'b', ' ', 'c' ], "texts: custom re" );
is_deeply( \@start_offsets, [ 0 .. 4 ], "starts: custom re" );
is_deeply( \@end_offsets,   [ 1 .. 5 ], "ends: custom re" );

$batch->reset;
$batch       = $tokenizer->analyze_batch($batch);
@token_texts = ();
while ( my $token = $batch->next ) {
    push @token_texts, $token->get_text;
}
is_deeply(
    \@token_texts,
    [ 'a', ' ', 'b', ' ', 'c' ],
    "no freakout when fed multiple tokens"
);

$batch->reset;
$tokenizer = KinoSearch::Analysis::Tokenizer->new();
$batch
    = $tokenizer->analyze_field( { monroe => 'some like it hot' }, 'monroe' );
@token_texts = ();
while ( my $token = $batch->next ) {
    push @token_texts, $token->get_text;
}
is_deeply( \@token_texts, [ 'some', 'like', 'it', 'hot' ], "analyze_field" );
