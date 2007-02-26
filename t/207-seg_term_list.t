use strict;
use warnings;

use Test::More tests => 5;

use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndexer;
use KinoSearch::Index::SegTermList;
use KinoSearch::Index::TermListReader;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Util::YAML qw( parse_yaml );
use KinoSearch::Util::CClass qw( to_kino );

package MySchema::a;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema::b;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema::c;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema;
use base qw( KinoSearch::Schema );

use KinoSearch::Analysis::Analyzer;

__PACKAGE__->init_fields(qw( a b c ));

sub analyzer { KinoSearch::Analysis::Analyzer->new }

package main;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->create(
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

my $seg_infos = KinoSearch::Index::SegInfos->new;
$seg_infos->read_infos($folder);
my $seg_info = $seg_infos->get_info('_1');

my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my %term_lists;
my $tl_reader = KinoSearch::Index::TermListReader->new(
    folder   => $cf_reader,
    schema   => $schema,
    seg_info => $seg_info,
);
for (qw( a b c )) {
    $term_lists{$_} = $tl_reader->start_field_terms($_);
}

my @fields;
my @texts;
for (qw( a b c )) {
    my $term_list = $term_lists{$_};
    while ( $term_list->next ) {
        my $term = $term_list->get_term;
        push @fields, $term->get_field;
        push @texts,  $term->get_text;
    }
}
is_deeply( \@fields, [qw( a a a b b b c c c )], "correct fields" );
my @correct_texts = (@animals) x 3;
is_deeply( \@texts, \@correct_texts, "correct terms" );

my $dog = KinoSearch::Index::Term->new( b => 'dog' );
my $term_list = $term_lists{b};
$term_list->seek($dog);
$term_list->next;
is( $term_list->get_term->get_text,
    'sloth', "term_list seeks to correct term (ptr)" );
is( $term_list->get_term->get_field, 'b', "term_list has correct field" );

$term_list->reset;
$term_list->next;
is( $term_list->get_term->get_text, 'cat', "reset" );
