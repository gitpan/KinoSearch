use strict;
use warnings;

use Test::More tests => 36;
use KinoSearch::Test;
use List::Util qw( shuffle );

my $hit_q = KinoSearch::Search::HitQueue->new( wanted => 10 );

my @docs_and_scores = (
    [ 0,    1.0 ],
    [ 5,    0.1 ],
    [ 10,   0.1 ],
    [ 1000, 0.9 ],
    [ 2000, 1.0 ],
    [ 3000, 1.0 ],
);

my @match_docs = map {
    KinoSearch::Search::MatchDoc->new(
        doc_id => $_->[0],
        score  => $_->[1],
        )
} @docs_and_scores;

my @correct_order = sort {
           $b->get_score <=> $a->get_score
        or $a->get_doc_id <=> $b->get_doc_id
} @match_docs;
my @correct_docs   = map { $_->get_doc_id } @correct_order;
my @correct_scores = map { $_->get_score } @correct_order;

$hit_q->insert($_) for @match_docs;
my $got = $hit_q->pop_all;

my @scores = map { $_->get_score } @$got;
is_deeply( \@scores, \@correct_scores, "rank by scores first" );

my @doc_ids = map { $_->get_doc_id } @$got;
is_deeply( \@doc_ids, \@correct_docs, "rank by doc_id after score" );

my $schema = KinoSearch::Plan::Schema->new;
my $type = KinoSearch::Plan::StringType->new( sortable => 1 );
$schema->spec_field( name => 'letter', type => $type );
$schema->spec_field( name => 'number', type => $type );
$schema->spec_field( name => 'id',     type => $type );

my $folder  = KinoSearch::Store::RAMFolder->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);

my @letters = 'a' .. 'z';
my @numbers = 1 .. 5;
my @docs;
for my $id ( 1 .. 100 ) {
    my $doc = {
        letter => $letters[ rand @letters ],
        number => $numbers[ rand @numbers ],
        id     => $id,
    };
    push @docs, $doc;
    $indexer->add_doc($doc);
}
$indexer->commit;
my $seg_reader = KinoSearch::Index::IndexReader->open( index => $folder );

my $by_letter = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'letter' ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ]
);
$hit_q = KinoSearch::Search::HitQueue->new(
    wanted    => 100,
    schema    => $schema,
    sort_spec => $by_letter,
);
for my $doc_id ( shuffle( 1 .. 100 ) ) {
    my $match_doc = KinoSearch::Search::MatchDoc->new(
        doc_id => $doc_id,
        score  => 1.0,
        values => [ $docs[ $doc_id - 1 ]{letter} ],
    );
    $hit_q->insert($match_doc);
}
my @wanted = map { $_->{id} }
    sort { $a->{letter} cmp $b->{letter} || $a->{id} <=> $b->{id} } @docs;
my @got = map { $_->get_doc_id } @{ $hit_q->pop_all };
is_deeply( \@got, \@wanted, "sort by letter then doc id" );

my $by_num_then_letter = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'number' ),
        KinoSearch::Search::SortRule->new( field => 'letter', reverse => 1 ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ]
);
$hit_q = KinoSearch::Search::HitQueue->new(
    wanted    => 100,
    schema    => $schema,
    sort_spec => $by_num_then_letter,
);
for my $doc_id ( shuffle( 1 .. 100 ) ) {
    my $doc       = $docs[ $doc_id - 1 ];
    my $match_doc = KinoSearch::Search::MatchDoc->new(
        doc_id => $doc_id,
        score  => 1.0,
        values => [ $doc->{number}, $doc->{letter} ],
    );
    $hit_q->insert($match_doc);
}
@wanted = map { $_->{id} }
    sort {
           $a->{number} <=> $b->{number}
        || $b->{letter} cmp $a->{letter}
        || $a->{id} <=> $b->{id}
    } @docs;
@got = map { $_->get_doc_id } @{ $hit_q->pop_all };
is_deeply( \@got, \@wanted, "sort by num then letter reversed then doc id" );

my $by_num_then_score = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'number' ),
        KinoSearch::Search::SortRule->new( type  => 'score' ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ]
);
$hit_q = KinoSearch::Search::HitQueue->new(
    wanted    => 100,
    schema    => $schema,
    sort_spec => $by_num_then_score,
);

for my $doc_id ( shuffle( 1 .. 100 ) ) {
    my $match_doc = KinoSearch::Search::MatchDoc->new(
        doc_id => $doc_id,
        score  => $doc_id,
        values => [ $docs[ $doc_id - 1 ]{number} ],
    );
    $hit_q->insert($match_doc);
}
@wanted = map { $_->{id} }
    sort { $a->{number} <=> $b->{number} || $b->{id} <=> $a->{id} } @docs;
@got = map { $_->get_doc_id } @{ $hit_q->pop_all };
is_deeply( \@got, \@wanted, "sort by num then score then doc id" );

$hit_q = KinoSearch::Search::HitQueue->new(
    wanted    => 100,
    schema    => $schema,
    sort_spec => $by_num_then_score,
);

for my $doc_id ( shuffle( 1 .. 100 ) ) {
    my $fields = $docs[ $doc_id - 1 ];
    my $values = KinoSearch::Object::VArray->new( capacity => 1 );
    $values->push( KinoSearch::Object::CharBuf->new( $fields->{number} ) );
    my $match_doc = KinoSearch::Search::MatchDoc->new(
        doc_id => $doc_id,
        score  => $doc_id,
        values => $values,
    );
    $hit_q->insert($match_doc);
}
@wanted = map { $_->{id} }
    sort { $a->{number} <=> $b->{number} || $b->{id} <=> $a->{id} } @docs;
@got = map { $_->get_doc_id } @{ $hit_q->pop_all };
is_deeply( \@got, \@wanted, "sort by value when no reader set" );

@docs_and_scores = ();
for ( 1 .. 30 ) {
    push @docs_and_scores, [ int( rand(10000) ) + 1, rand(10) ];
}
@docs_and_scores = sort { $b->[1] <=> $a->[1] } @docs_and_scores;
@doc_ids         = map  { $_->[0] } @docs_and_scores;

@match_docs = map {
    KinoSearch::Search::MatchDoc->new(
        doc_id => $_->[0],
        score  => $_->[1],
        )
} sort { $a->[0] <=> $b->[0] } @docs_and_scores;

for my $size ( 0 .. $#match_docs ) {
    $hit_q = KinoSearch::Search::HitQueue->new( wanted => $size, );
    $hit_q->insert($_) for @match_docs;

    if ($size) {
        @wanted = @doc_ids[ 0 .. $size - 1 ];
    }
    else {
        @wanted = ();
    }
    @got = map { $_->get_doc_id } @{ $hit_q->pop_all };
    is_deeply( \@got, \@wanted, "random docs and scores, size $size" );
}

