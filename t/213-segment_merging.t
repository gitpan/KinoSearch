use strict;
use warnings;
use lib 'buildlib';

# BiggerSchema is like TestSchema, but it has an extra field named "aux".
# Because "aux" sorts before "content", it forces a remapping of field numbers
# when an invindex created under TestSchema is opened/modified under
# BiggerSchema.
package BiggerSchema;
use base qw( TestSchema );
use KinoSearch::Analysis::Tokenizer;

our %fields = (
    content => 'text',
    aux     => 'text',
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 7;

use KinoSearch::InvIndexer;
use KinoSearch::InvIndex;
use KinoSearch::Searcher;
use KinoSearch::Index::IndexReader;

use TestSchema;
use KinoTestUtils qw( create_invindex init_test_invindex_loc );

{    # wrap script in a block, so we can test object destruction at end

    my ( $invindex, $invindexer, $searcher, $hits );

    my $invindex_loc = init_test_invindex_loc();
    TestSchema->clobber($invindex_loc);

    sub init_invindexer {
        undef $invindex;
        undef $invindexer;
        $invindex = TestSchema->open($invindex_loc);
        $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    }

    my @correct;
    for my $num_letters ( reverse 1 .. 10 ) {
        init_invindexer();

        for my $letter ( 'a' .. 'b' ) {
            my $content = ( "$letter " x $num_letters ) . ( 'z ' x 50 );
            $invindexer->add_doc( { content => $content } );
            push @correct, $content if $letter eq 'b';
        }
        $invindexer->finish;
    }

    $searcher = KinoSearch::Searcher->new(
        invindex => TestSchema->read($invindex_loc) );
    $hits = $searcher->search( query => 'b' );
    is( $hits->total_hits, 10, "correct total_hits from merged invindex" );
    my @got;
    push @got, $hits->fetch_hit_hashref->{content} for 1 .. $hits->total_hits;
    is_deeply( \@got, \@correct,
        "correct top scoring hit from merged invindex" );

    # reopen invindex under BiggerSchema and add some content.
    undef $invindexer;
    $invindexer = KinoSearch::InvIndexer->new(
        invindex => BiggerSchema->open($invindex_loc) );
    $invindexer->add_doc( { aux => 'foo', content => 'bar' } );

    # now add some invindexes
    my $another_invindex = create_invindex( "atlantic ocean", "fresh fish" );
    my $yet_another_invindex = create_invindex("bonus");
    my $another_folder       = $another_invindex->get_folder;
    my $yet_another_folder   = $yet_another_invindex->get_folder;
    $another_invindex = KinoSearch::InvIndex->open(
        folder => $another_folder,
        schema => BiggerSchema->new
    );
    $yet_another_invindex = KinoSearch::InvIndex->open(
        folder => $yet_another_folder,
        schema => BiggerSchema->new
    );
    $invindexer->add_invindexes( $another_invindex, $yet_another_invindex );
    $invindexer->finish;

    $searcher = KinoSearch::Searcher->new(
        invindex => BiggerSchema->read($invindex_loc) );
    $hits = $searcher->search( query => 'fish' );
    is( $hits->total_hits, 1, "correct total_hits after add_invindexes" );
    is( $hits->fetch_hit_hashref->{content},
        'fresh fish', "other invindexes successfully absorbed" );
    undef $searcher;
    undef $hits;

    # Open an IndexReader, to prevent the deletion of files on Win32 and
    # verify the file purging mechanism.
    my $reader = KinoSearch::Index::IndexReader->open(
        invindex => BiggerSchema->read($invindex_loc) );
    $invindexer = KinoSearch::InvIndexer->new(
        invindex => BiggerSchema->open($invindex_loc) );
    $invindexer->finish( optimize => 1 );
    $reader->close;
    $invindexer = KinoSearch::InvIndexer->new(
        invindex => BiggerSchema->open($invindex_loc) );
    $invindexer->finish( optimize => 1 );
    opendir( my $invindex_dh, $invindex_loc )
        or die "Couldn't opendir '$invindex_loc': $!";
    my @cf_files = grep {m/\.cf$/} readdir $invindex_dh;
    closedir $invindex_dh, $invindex_loc
        or die "Couldn't closedir '$invindex_loc': $!";
    is( scalar @cf_files, 1, "merged segment files successfully deleted" );

    undef $invindexer;
    undef $reader;
}

is( KinoSearch::Store::FileDes::object_count(),
    0, "All FileDes objects have been cleaned up" );
is( KinoSearch::Store::FileDes::open_count(), 0, "All FileDes closed" );
