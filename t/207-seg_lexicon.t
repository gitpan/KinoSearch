use strict;
use warnings;

use Test::More tests => 5;

package TestAnalyzer;
use base qw( KinoSearch::Analysis::Analyzer );
sub analyze_batch { $_[1] }

package MySchema;
use base qw( KinoSearch::Schema );

our %fields = (
    a => 'KinoSearch::Schema::FieldSpec',
    b => 'KinoSearch::Schema::FieldSpec',
    c => 'KinoSearch::Schema::FieldSpec',
);

sub analyzer { TestAnalyzer->new }

package main;

use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Index::SegLexicon;
use KinoSearch::Index::LexReader;
use KinoSearch::Index::Term;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Util::YAML qw( parse_yaml );
use KinoSearch::Util::Native qw( to_kino );

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
my @animals = qw( cat dog sloth );
for my $animal (@animals) {
    $invindexer->add_doc(
        {   a => $animal,
            b => $animal,
            c => $animal,
        }
    );
}
$invindexer->finish;

my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos( folder => $folder );
my $seg_info = $seg_infos->get_info('_1');

my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my %lexicons;
my $lex_reader = KinoSearch::Index::LexReader->new(
    folder   => $cf_reader,
    schema   => $schema,
    seg_info => $seg_info,
);
for (qw( a b c )) {
    $lexicons{$_} = $lex_reader->look_up_field($_);
}

my @fields;
my @texts;
for (qw( a b c )) {
    my $lexicon = $lexicons{$_};
    while ( $lexicon->next ) {
        my $term = $lexicon->get_term;
        push @fields, $term->get_field;
        push @texts,  $term->get_text;
    }
}
is_deeply( \@fields, [qw( a a a b b b c c c )], "correct fields" );
my @correct_texts = (@animals) x 3;
is_deeply( \@texts, \@correct_texts, "correct terms" );

my $dog = KinoSearch::Index::Term->new( b => 'dog' );
my $lexicon = $lexicons{b};
$lexicon->seek($dog);
$lexicon->next;
is( $lexicon->get_term->get_text,
    'sloth', "lexicon seeks to correct term (ptr)" );
is( $lexicon->get_term->get_field, 'b', "lexicon has correct field" );

$lexicon->reset;
$lexicon->next;
is( $lexicon->get_term->get_text, 'cat', "reset" );
