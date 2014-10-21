use strict;
use warnings;
use lib 'buildlib';

package MySchema;
use base qw( KinoSearch::Plan::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $class      = shift;
    my $self       = $class->SUPER::new(@_);
    my $tokenizer  = KinoSearch::Analysis::Tokenizer->new;
    my $plain_type = KinoSearch::Plan::FullTextType->new(
        analyzer      => $tokenizer,
        highlightable => 1,
    );
    my $dunked_type = KinoSearch::Plan::FullTextType->new(
        analyzer      => $tokenizer,
        highlightable => 1,
        boost         => 0.1,
    );
    $self->spec_field( name => 'content', type => $plain_type );
    $self->spec_field( name => 'alt',     type => $dunked_type );
    return $self;
}

package MyHighlighter;
use base qw( KinoSearch::Highlight::Highlighter );

sub encode {
    my ( $self, $text ) = @_;
    $text =~ s/blind/wise/;
    return $text;
}

sub highlight {
    my ( $self, $text ) = @_;
    return "*$text*";
}

package main;

use Test::More tests => 34;
use KinoSearch::Test;

binmode( STDOUT, ":utf8" );

my $phi         = "\x{03a6}";
my $encoded_phi = "&#934;";

my $string = '1 2 3 4 5 ' x 20;    # 200 characters
$string .= "$phi a b c d x y z h i j k ";
$string .= '6 7 8 9 0 ' x 20;
my $with_quotes = '"I see," said the blind man.';

my $folder  = KinoSearch::Store::RAMFolder->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => MySchema->new,
);

$indexer->add_doc( { content => $_ } ) for ( $string, $with_quotes );
$indexer->add_doc(
    {   content => "x but not why or 2ee",
        alt     => $string . " and extra stuff so it scores lower",
    }
);
$indexer->commit;

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $q    = qq|"x y z" AND $phi|;
my $hits = $searcher->hits( query => $q );
my $hl   = KinoSearch::Highlight::Highlighter->new(
    searcher       => $searcher,
    query          => $q,
    field          => 'content',
    excerpt_length => 3,
);

my $target = KinoSearch::Object::ViewCharBuf->_new("");

my $field_val = make_cb("a $phi $phi b c");
my $top       = $hl->_find_best_fragment(
    fragment  => $target,
    field_val => $field_val,
    heat_map  => make_heat_map( [ 2, 1, 1.0 ] ),
);
is( $target->to_perl, "$phi $phi b", "Find_Best_Fragment" );
is( $top, 2, "correct offset returned by Find_Best_Fragment" );

$field_val = make_cb("aa$phi");
$top       = $hl->_find_best_fragment(
    fragment  => $target,
    field_val => $field_val,
    heat_map  => make_heat_map( [ 2, 1, 1.0 ] ),
);
is( $target->to_perl, $field_val->to_perl,
    "Find_Best_Fragment returns whole field when field is short" );
is( $top, 0, "correct offset" );

$field_val = make_cb("aaaab$phi$phi");
$top       = $hl->_find_best_fragment(
    fragment  => $target,
    field_val => $field_val,
    heat_map  => make_heat_map( [ 6, 2, 1.0 ] ),
);
is( $target->to_perl, "b$phi$phi",
    "Find_Best_Fragment shifts left to deal with overrun" );
is( $top, 4, "correct offset" );

$field_val = make_cb( "a$phi" . "bcde" );
$top       = $hl->_find_best_fragment(
    fragment  => $target,
    field_val => $field_val,
    heat_map  => make_heat_map( [ 0, 1, 1.0 ] ),
);
is( $target->to_perl,
    "a$phi" . "bcd",
    "Find_Best_Fragment start at field beginning"
);
is( $top, 0, "correct offset" );
undef $target;

$hl = KinoSearch::Highlight::Highlighter->new(
    searcher       => $searcher,
    query          => $q,
    field          => 'content',
    excerpt_length => 6,
);

$target    = make_cb("");
$field_val = "Ook.  Urk.  Ick.  ";
$top       = $hl->_raw_excerpt(
    field_val   => $field_val,
    fragment    => "Ook.  Urk.",
    raw_excerpt => $target,
    top         => 0,
    sentences   => make_spans( [ 0, 4, 0 ], [ 6, 4, 0 ] ),
    heat_map => make_heat_map( [ 0, length($field_val), 1.0 ] ),
);
is( $target->to_perl, "Ook.", "Raw_Excerpt at top" );
is( $top,             0,      "top still 0" );

$target    = make_cb("");
$field_val = "Ook.  Urk.  Ick.  ";
$top       = $hl->_raw_excerpt(
    field_val   => $field_val,
    fragment    => ".  Urk.  I",
    raw_excerpt => $target,
    top         => 3,
    sentences   => make_spans( [ 6, 4, 0 ], [ 12, 4, 0 ] ),
    heat_map => make_heat_map( [ 0, length($field_val), 1.0 ] ),
);
is( $target->to_perl, "Urk.", "Raw_Excerpt in middle, with 2 bounds" );
is( $top,             6,      "top in the middle modified by Raw_Excerpt" );

$target    = make_cb("");
$field_val = "Ook urk ick i.";
$top       = $hl->_raw_excerpt(
    field_val   => $field_val,
    fragment    => "ick i.",
    raw_excerpt => $target,
    top         => 8,
    sentences   => make_spans( [ 0, length($field_val), 0 ] ),
    heat_map    => make_heat_map( [ 0, length($field_val), 1.0 ] ),
);
is( $target->to_perl, "\x{2026} i.", "Ellipsis at top" );
is( $top, 10, "top correct when leading ellipsis inserted" );

$target    = make_cb("");
$field_val = "Urk.  Iz no good.";
$top       = $hl->_raw_excerpt(
    field_val   => $field_val,
    fragment    => "  Iz no go",
    raw_excerpt => $target,
    top         => 4,
    sentences   => make_spans( [ 6, length($field_val) - 6, 0 ] ),
    heat_map    => make_heat_map( [ 0, length($field_val), 1.0 ] ),
);
is( $target->to_perl, "Iz no\x{2026}", "Ellipsis at end" );
is( $top, 6, "top trimmed" );

$hl = KinoSearch::Highlight::Highlighter->new(
    searcher       => $searcher,
    query          => $q,
    field          => 'content',
    excerpt_length => 3,
);

$target = make_cb("");
$hl->_highlight_excerpt(
    raw_excerpt => 'a b c',
    spans       => make_spans( [ 2, 1 ] ),
    top         => 0,
    highlighted => $target,
);
is( $target->to_perl, "a <strong>b</strong> c", "basic Highlight_Excerpt" );

$target = make_cb("");
$hl->_highlight_excerpt(
    raw_excerpt => "$phi $phi $phi",
    spans       => make_spans( [ 2, 1, 1.0 ] ),
    top         => 0,
    highlighted => $target,
);
like(
    $target->to_perl,
    qr#$encoded_phi <strong>$encoded_phi</strong> $encoded_phi#i,
    "encode invoked by Highlight_Excerpt"
);

$target = make_cb("");
$hl->_highlight_excerpt(
    raw_excerpt => "$phi $phi $phi",
    spans       => make_spans( [ 3, 1, 1.0 ] ),
    top         => 1,
    highlighted => $target,
);
like(
    $target->to_perl,
    qr#^$encoded_phi <strong>$encoded_phi</strong> $encoded_phi$#i,
    "Highlight_Excerpt pays attention to offset"
);

$hl = KinoSearch::Highlight::Highlighter->new(
    searcher => $searcher,
    query    => $q,
    field    => 'content',
);

my $hit     = $hits->next;
my $excerpt = $hl->create_excerpt($hit);
like( $excerpt, qr/$encoded_phi.*?z/i,
    "excerpt contains all relevant terms" );
like( $excerpt, qr#<strong>x y z</strong>#, "highlighter tagged the phrase" );
like(
    $excerpt,
    qr#<strong>$encoded_phi</strong>#i,
    "highlighter tagged the single term"
);

$hl->set_pre_tag("\e[1m");
$hl->set_post_tag("\e[0m");
like(
    $hl->create_excerpt($hit),
    qr#\e\[1m$encoded_phi\e\[0m#i, "set_pre_tag and set_post_tag",
);

like( $hl->create_excerpt( $hits->next() ),
    qr/x/,
    "excerpt field with partial hit doesn't cause highlighter freakout" );

$hits = $searcher->hits( query => $q = 'x "x y z" AND b' );
$hl = KinoSearch::Highlight::Highlighter->new(
    searcher => $searcher,
    query    => $q,
    field    => 'content',
);
$excerpt = $hl->create_excerpt( $hits->next() );
$excerpt =~ s#</?strong>##g;
like( $excerpt, qr/x y z/,
    "query with same word in both phrase and term doesn't cause freakout" );

$hits = $searcher->hits( query => $q = 'blind' );
like(
    KinoSearch::Highlight::Highlighter->new(
        searcher => $searcher,
        query    => $q,
        field    => 'content',
        )->create_excerpt( $hits->next() ),
    qr/quot/,
    "HTML entity encoded properly"
);

$hits = $searcher->hits( query => $q = 'why' );
unlike(
    KinoSearch::Highlight::Highlighter->new(
        searcher => $searcher,
        query    => $q,
        field    => 'content',
        )->create_excerpt( $hits->next() ),
    qr/\.\.\./,
    "no ellipsis for short excerpt"
);

my $term_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'x',
);
$hits = $searcher->hits( query => $term_query );
$hit = $hits->next();
like(
    KinoSearch::Highlight::Highlighter->new(
        searcher => $searcher,
        query    => $term_query,
        field    => 'content',
        )->create_excerpt($hit),
    qr/strong/,
    "specify field highlights correct field..."
);
unlike(
    KinoSearch::Highlight::Highlighter->new(
        searcher => $searcher,
        query    => $term_query,
        field    => 'alt',
        )->create_excerpt($hit),
    qr/strong/,
    "... but not another field"
);

my $sentence_text = 'This is a sentence. ' x 15;
$hl = KinoSearch::Highlight::Highlighter->new(
    searcher => $searcher,
    query    => $q,
    field    => 'content',
);
my $sentences = $hl->find_sentences(
    text   => $sentence_text,
    offset => 101,
    length => 50,
);
is_deeply(
    spans_to_arg_array($sentences),
    [ [ 120, 19, 0 ], [ 140, 19, 0 ] ],
    'find_sentences with explicit args'
);

$sentences = $hl->find_sentences(
    text   => $sentence_text,
    offset => 101,
    length => 4,
);
is_deeply( spans_to_arg_array($sentences),
    [], 'find_sentences with explicit args, finding nothing' );

my @expected;
for my $i ( 0 .. 14 ) {
    push @expected, [ $i * 20, 19, 0 ];
}
$sentences = $hl->find_sentences( text => $sentence_text );
is_deeply( spans_to_arg_array($sentences),
    \@expected, 'find_sentences with default offset and length' );

$sentences = $hl->find_sentences( text => ' Foo' );
is_deeply(
    spans_to_arg_array($sentences),
    [ [ 1, 3, 0 ] ],
    "Skip leading whitespace but get first sentence"
);

$hl = MyHighlighter->new(
    searcher => $searcher,
    query    => "blind",
    field    => 'content',
);
$hits = $searcher->hits( query => 'blind' );
$hit = $hits->next;
like( $hl->create_excerpt($hit),
    qr/\*wise\*/, "override both Encode() and Highlight()" );

sub make_cb {
    return KinoSearch::Object::CharBuf->new(shift);
}

sub make_heat_map {
    return KinoSearch::Highlight::HeatMap->new( spans => make_spans(@_) );
}

sub make_span {
    return KinoSearch::Search::Span->new(
        offset => $_[0],
        length => $_[1],
        weight => $_[2],
    );
}

sub make_spans {
    my $spans = KinoSearch::Object::VArray->new( capacity => scalar @_ );
    for my $span_spec (@_) {
        $spans->push( make_span( @{$span_spec}[ 0 .. 2 ] ) );
    }
    return $spans;
}

sub spans_to_arg_array {
    my $spans = shift;
    my @out;
    for (@$spans) {
        push @out, [ $_->get_offset, $_->get_length, $_->get_weight ];
    }
    return \@out;
}
