package KinoSearchTestInvIndex;
use strict;
use warnings;
use base qw( Exporter );

our @EXPORT_OK = qw( 
    create_invindex 
    create_test_invindex 
    get_uscon_docs
);

use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMInvIndex;
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::PolyAnalyzer;

use File::Spec::Functions qw( catdir catfile );

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
    opendir( USCON_DIR, $uscon_dir )
        or die "couldn't open directory '$uscon_dir': $!";
    my @filenames = grep {/\.html$/} sort readdir USCON_DIR;

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

sub create_test_invindex {
    my $invindexer;
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new( 
        language => 'en' );

    $invindexer = KinoSearch::InvIndexer->new(
        invindex => 'test_invindex',
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
        invindex => 'test_invindex',
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
        invindex => 'test_invindex',
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