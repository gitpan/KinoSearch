use strict;
use warnings;
use lib 'buildlib';

use strict;
use warnings;

package MySchema::UnAnalyzed;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'MySchema::UnAnalyzed' );

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 49;
use File::Spec::Functions qw( catfile );

use KinoSearch::Index::MultiLexicon;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Index::IndexReader;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::Term;
use KinoSearch::Store::RAMFolder;

my @docs = ( ( ("a") x 100 ), 'j', "Foo" );
my @chars = ( 'a' .. 'z' );
for ( 0 .. 100 ) {
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

# remember where 'j' exists in our 'correct' list
my $correct_term_num = 0;
for (@correct) {
    last if $correct[$correct_term_num] eq 'j';
    $correct_term_num++;
}

for my $index_interval ( 1, 2, 3, 4, 7, 128, 1024 ) {

    no warnings 'once';
    local *MySchema::index_interval = sub {$index_interval};

    my $folder   = KinoSearch::Store::RAMFolder->new;
    my $schema   = MySchema->new;
    my $invindex = KinoSearch::InvIndex->clobber(
        folder => $folder,
        schema => $schema,
    );

    my @docs_copy = @docs;
    while (@docs_copy) {
        my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
        my $docs_this_seg = int( rand(@docs_copy) );
        $docs_this_seg = 10 if $docs_this_seg < 10;

        for ( 0 .. 10 ) {
            last unless @docs_copy;
            my $tick = int( rand(@docs_copy) );
            $invindexer->add_doc(
                { content => splice( @docs_copy, $tick, 1 ) } );
        }
        $invindexer->finish;
    }

    my $reader
        = KinoSearch::Index::IndexReader->open( invindex => $invindex );

    my $lexicon = $reader->look_up_field('content');
    isa_ok( $lexicon, "KinoSearch::Index::MultiLexicon" );

    my @got;
    while ( $lexicon->next ) {
        push @got, $lexicon->get_term->get_text;
    }

    is_deeply( \@got, \@correct,
        "correct order for random strings (interval: $index_interval)" );

    my $intmap = $lexicon->build_sort_cache(
        max_doc      => $reader->max_doc,
        posting_list => $reader->posting_list( field => 'content' ),
    );
    isa_ok( $intmap, 'KinoSearch::Util::IntMap' );

    my $term = KinoSearch::Index::Term->new( content => 'j' );
    $lexicon->seek($term);
    is( $lexicon->get_term->get_text,
        'j', "seek (interval: $index_interval)" );

    is( $lexicon->get_term_num, $correct_term_num,
        "correct term number (interval: $index_interval)" );

    # get a sort cache, which as a side effect, caches a LexCache.
    $reader->fetch_sort_cache('content');
    $lexicon = $reader->look_up_field('content');
    $lexicon->seek($term);
    is( $lexicon->get_term->get_text,
        'j', "seek (interval: $index_interval)" );
    pass("Lexicon obtained after building sort cache can seek");
}
