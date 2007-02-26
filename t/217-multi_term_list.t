use strict;
use warnings;
use lib 'buildlib';

use strict;
use warnings;

package MySchema::content;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

__PACKAGE__->init_fields(qw( content ));

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 8;
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::Index::MultiTermList') }

use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::Term;
use KinoSearch::Store::RAMFolder;

my $folder   = KinoSearch::Store::RAMFolder->new;
my $schema   = MySchema->new;
my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);

my @docs = ( ( 1 .. 1000 ), ( ("a") x 100 ), 'b', , "Foo", );
my @chars = ( 'a' .. 'z' );
for ( 0 .. 1000 ) {
    my $content = '';
    for my $num_chars ( 1 .. int( rand(10) + 1 ) ) {
        $content .= @chars[ rand(@chars) ];
    }
    push @docs, "$content";
}

# accumulate unique sorted terms.
my @correct = ();
for ( sort @docs ) {
    next if ( @correct and $_ eq $correct[-1] );
    push @correct, $_;
}

while (@docs) {
    my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    for ( 0 .. 10 ) {
        last unless @docs;
        my $tick = int( rand(@docs) );
        $invindexer->add_doc( { content => splice( @docs, $tick, 1 ) } );
    }
    $invindexer->finish;
}

my $ix_reader = KinoSearch::Index::IndexReader->new( invindex => $invindex );

my $term_list = $ix_reader->start_field_terms('content');
isa_ok( $term_list, "KinoSearch::Index::MultiTermList" );

my @got;
while ( $term_list->next ) {
    push @got, $term_list->get_term->get_text;
}

is_deeply( \@got, \@correct, "correct order for random strings" );

my $intmap = $term_list->build_sort_cache(
    max_doc   => $ix_reader->max_doc,
    term_docs => $ix_reader->term_docs,
);
isa_ok( $intmap, 'KinoSearch::Util::IntMap' );

my $term = KinoSearch::Index::Term->new( content => 'b' );
$term_list->seek($term);
is( $term_list->get_term->get_text, 'b', "seek" );

my $term_num = $term_list->get_term_num;
is( $correct[$term_num], 'b', "correct term number" );

# get a sort cache, which as a side effect, caches a TLCache.
$ix_reader->fetch_sort_cache('content');
$term_list = $ix_reader->start_field_terms('content');
$term_list->seek($term);
is( $term_list->get_term->get_text, 'b', "seek" );
pass("TermList obtained after building sort cache can seek"); 

