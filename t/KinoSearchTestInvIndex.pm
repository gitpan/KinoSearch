package KinoSearchTestInvIndex;
use strict;
use warnings;
use base qw( Exporter );

our @EXPORT_OK = qw( 
    working_dir
    create_working_dir
    remove_working_dir
    create_invindex 
    create_persistent_test_invindex 
    init_test_invindex_loc
    test_invindex_loc
    persistent_test_invindex_loc
    get_uscon_docs
);

use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMInvIndex;
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::PolyAnalyzer;

use File::Spec::Functions qw( catdir catfile tmpdir );
use File::Path qw( rmtree );

my $working_dir = catfile( tmpdir(), 'kinosearch_test' );

# Return a directory within the system's temp directory where we will put all
# testing scratch files.
sub working_dir { $working_dir }

sub create_working_dir {
    mkdir( $working_dir, 0700 ) or die "Can't mkdir '$working_dir': $!";
}

# Verify that this user owns the working dir, then zap it.  Returns true upon
# success.
sub remove_working_dir {
    my $mode = (stat $working_dir)[2];
    return unless -d $working_dir;
    $mode &= 07777;
    return unless $mode == 0700;
    rmtree $working_dir;
    return 1;
}

# Return a location for a test invindex to be used by a single test file.  If
# the test file crashes it cannot clean up after itself, so we put the cleanup
# routine in a single test file to be run at or near the end of the test
# suite.
sub test_invindex_loc {
    return catdir( $working_dir, 'test_invindex' );
}

# Return a location for a test invindex intended to be shared by multiple
# test files.  It will be cleaned as above.
sub persistent_test_invindex_loc {
    return catdir( $working_dir, 'persistent_test_invindex' );
}

# Destroy anything left over in the test_invindex location, then create the
# directory.  Finally, return the path.
sub init_test_invindex_loc {
    my $dir = test_invindex_loc();
    rmtree $dir;
    die "Can't clean up '$dir'" if -e $dir;
    mkdir $dir or die "Can't mkdir '$dir': $!";
    return $dir;
}

# Build a RAMInvIndex, using the supplied array of strings as source material.
# The invindex will have a single field: "content".
sub create_invindex {
    my @docs = @_;

    my $tokenizer  = KinoSearch::Analysis::Tokenizer->new;
    my $invindex   = KinoSearch::Store::RAMInvIndex->new;
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $invindex,
        analyzer => $tokenizer,
        create   => 1,
    );

    $invindexer->spec_field( name => 'content' );

    for (@docs) {
        my $doc = $invindexer->new_doc;
        $doc->set_value( content => $_ );
        $invindexer->add_doc($doc);
    }

    $invindexer->finish;

    return $invindex;
}

# Slurp us constitition docs and build hashrefs.
sub get_uscon_docs {

    my $uscon_dir = catdir( 't', 'us_constitution' );
    opendir( my $uscon_dh, $uscon_dir )
        or die "couldn't opendir '$uscon_dir': $!";
    my @filenames = grep {/\.html$/} sort readdir $uscon_dh;
    closedir $uscon_dh or die "couldn't closedir '$uscon_dir': $!";

    my %docs;

    for my $filename (@filenames) {
        next if $filename eq 'index.html';
        my $filepath = catfile( $uscon_dir, $filename );
        open( my $fh, '<', $filepath )
            or die "couldn't open file '$filepath': $!";
        my $content = do { local $/; <$fh> };
        $content =~ m#<title>(.*?)</title>#s
            or die "couldn't isolate title in '$filepath'";
        my $title = $1;
        $content =~ m#<div id="bodytext">(.*?)</div><!--bodytext-->#s
            or die "couldn't isolate bodytext in '$filepath'";
        my $bodytext = $1;
        $bodytext =~ s/<.*?>//sg;
        $bodytext =~ s/\s+/ /sg;

        $docs{$filename} = {
            title    => $title,
            bodytext => $bodytext,
            url      => "/us_constitution/$filename",
        }
    }

    return \%docs;
}

sub create_persistent_test_invindex {
    my $invindexer;
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new( 
        language => 'en' );

    $invindexer = KinoSearch::InvIndexer->new(
        invindex => persistent_test_invindex_loc(),
        create => 1,
        analyzer => $polyanalyzer,
    );
    $invindexer->spec_field( name => 'content' );
    for (0 .. 10000) {
        my $doc = $invindexer->new_doc;
        $doc->set_value( content => "zz$_" );
        $invindexer->add_doc($doc);
    }
    $invindexer->finish;
    undef $invindexer;

    $invindexer = KinoSearch::InvIndexer->new(
        invindex => persistent_test_invindex_loc(),
        analyzer => $polyanalyzer,
    );
    $invindexer->spec_field( name => 'content' );
    my $source_docs = get_uscon_docs();
    for (values %$source_docs) {
        my $doc = $invindexer->new_doc;
        $doc->set_value( content => $_->{bodytext} );
        $invindexer->add_doc($doc);
    }
    $invindexer->finish;
    undef $invindexer;

    $invindexer = KinoSearch::InvIndexer->new(
        invindex => persistent_test_invindex_loc(),
        analyzer => $polyanalyzer,
    );
    $invindexer->spec_field( name => 'content' );
    my @chars = ( 'a' .. 'z' );
    for ( 0 .. 1000 ) {
        my $content = '';
        for my $num_words ( 1 .. int( rand(20) ) ) {
            for ( 1 .. (int( rand(10) ) + 10) ) {
                $content .= @chars[ rand(@chars) ];
            }
            $content .= ' ';
        }
        my $doc = $invindexer->new_doc;
        $doc->set_value( content => $content );
        $invindexer->add_doc($doc);
    }
    $invindexer->finish( optimize => 1 );
}

1;