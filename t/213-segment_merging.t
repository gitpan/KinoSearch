use strict;
use warnings;

use lib 't';
use Test::More tests => 9;
use File::Spec::Functions qw( catfile tmpdir );
use File::Path qw( rmtree );

BEGIN {
    use_ok('KinoSearch::InvIndexer');
    use_ok('KinoSearch::Searcher');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Index::IndexReader');
}
use KinoSearchTestInvIndex qw( create_invindex );

my $invindex_loc = catfile( tmpdir(), 'test_merging_invindex' );
my ( $invindexer, $searcher, $hits, $another_invindex,
    $yet_another_invindex );
my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

sub init_invindexer {
    undef $invindexer;
    $invindexer = KinoSearch::InvIndexer->new(
        invindex => $invindex_loc,
        analyzer => $tokenizer,
        @_,
    );
    $invindexer->spec_field( name => 'letters' );
}

my $create = 1;
my @correct;
for my $num_letters ( reverse 1 .. 10 ) {
    init_invindexer( create => $create );
    $create = 0;
    for my $letter ( 'a' .. 'b' ) {
        my $doc     = $invindexer->new_doc;
        my $content = ( "$letter " x $num_letters ) . 'z';

        $doc->set_value( letters => $content );
        $invindexer->add_doc($doc);
        push @correct, $content if $letter eq 'b';
    }
    $invindexer->finish;
}

$searcher = KinoSearch::Searcher->new(
    invindex => $invindex_loc,
    analyzer => $tokenizer,
);
$hits = $searcher->search( query => 'b' );
is( $hits->total_hits, 10, "correct total_hits from merged invindex" );
my @got;
push @got, $hits->fetch_hit_hashref->{letters} for 1 .. $hits->total_hits;
is_deeply( \@got, \@correct, "correct top scoring hit from merged invindex" );

init_invindexer();
$another_invindex = create_invindex( "atlantic ocean", "fresh fish" );
$yet_another_invindex = create_invindex("bonus");
$invindexer->add_invindexes( $another_invindex, $yet_another_invindex );
$invindexer->finish;
$searcher = KinoSearch::Searcher->new(
    invindex => $invindex_loc,
    analyzer => $tokenizer,
);
$hits = $searcher->search( query => 'fish' );
is( $hits->total_hits, 1, "correct total_hits after add_invindexes" );
is( $hits->fetch_hit_hashref->{content},
    'fresh fish', "other invindexes successfully absorbed" );
undef $searcher;
undef $hits;

# Open an IndexReader, to prevent the deletion of files on Win32 and verify
# the deletequeue mechanism.
my $reader
    = KinoSearch::Index::IndexReader->new( invindex => $invindex_loc, );
init_invindexer();
$invindexer->finish( optimize => 1 );
$reader->close;
init_invindexer();
$invindexer->finish( optimize => 1 );
opendir( my $invindex_dh, $invindex_loc )
    or die "Couldn't opendir '$invindex_loc': $!";
my @cfs_files = grep {m/\.cfs$/} readdir $invindex_dh;
closedir $invindex_dh, $invindex_loc
    or die "Couldn't closedir '$invindex_loc': $!";
is( scalar @cfs_files, 1, "merged segment files successfully deleted" );

rmtree($invindex_loc);
