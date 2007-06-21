use strict;
use warnings;

package KinoTestUtils;
use base qw( Exporter );

our @EXPORT_OK = qw(
    create_invindex
    create_uscon_invindex
    path_for_test_invindex
    get_uscon_docs
    utf8_test_strings
    test_analyzer
);

use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Store::FSFolder;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Index::PostingsWriter;

# set mem_thesh to 1 kiB in order to expose problems with flushing
$KinoSearch::Index::PostingsWriter::instance_vars{mem_thresh} = 0x400;

use lib 'sample';

use USConSchema;
use TestSchema;

use File::Spec::Functions qw( catdir catfile tmpdir );
use Encode qw( _utf8_off );

# Build a RAMInvIndex, using the supplied array of strings as source material.
# The invindex will have a single field: "content".
sub create_invindex {
    my @docs = @_;

    my $folder   = KinoSearch::Store::RAMFolder->new;
    my $invindex = KinoSearch::InvIndex->clobber(
        schema => TestSchema->new,
        folder => $folder,
    );

    my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );
    $invindexer->add_doc( { content => $_ } ) for @docs;
    $invindexer->finish;

    return $invindex;
}

# Slurp us constitition docs and build hashrefs.
sub get_uscon_docs {

    my $uscon_dir = catdir( 'sample', 'us_constitution' );
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
        };
    }

    return \%docs;
}

sub path_for_test_invindex {
    return catdir( tmpdir(), 'test_invindex' );
}

sub create_uscon_invindex {
    my $invindex = USConSchema->clobber( path_for_test_invindex() );
    my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );

    $invindexer->add_doc( { content => "zz$_" } ) for ( 0 .. 10000 );
    $invindexer->finish;
    undef $invindexer;

    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    my $source_docs = get_uscon_docs();
    $invindexer->add_doc( { content => $_->{bodytext} } )
        for values %$source_docs;
    $invindexer->finish;
    undef $invindexer;

    $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );
    my @chars = ( 'a' .. 'z' );
    for ( 0 .. 1000 ) {
        my $content = '';
        for my $num_words ( 1 .. int( rand(20) ) ) {
            for ( 1 .. ( int( rand(10) ) + 10 ) ) {
                $content .= @chars[ rand(@chars) ];
            }
            $content .= ' ';
        }
        $invindexer->add_doc( { content => $content } );
    }
    $invindexer->finish( optimize => 1 );
}

# Return 3 strings useful for verifying UTF-8 integrity.
sub utf8_test_strings {
    my $smiley       = "\x{263a}";
    my $not_a_smiley = $smiley;
    _utf8_off($not_a_smiley);
    my $frowny = $not_a_smiley;
    utf8::upgrade($frowny);
    return ( $smiley, $not_a_smiley, $frowny );
}

# Verify an Analyzer's analyze_batch, analyze_field, analyze_text, and analyze_raw methods.
sub test_analyzer {
    my ( $analyzer, $source, $expected, $message ) = @_;

    my $batch = KinoSearch::Analysis::TokenBatch->new( text => $source );
    $batch = $analyzer->analyze_batch($batch);
    my @got;
    while ( my $token = $batch->next ) {
        push @got, $token->get_text;
    }
    Test::More::is_deeply( \@got, $expected, "analyze: $message" );

    $batch = $analyzer->analyze_text($source);
    @got   = ();
    while ( my $token = $batch->next ) {
        push @got, $token->get_text;
    }
    Test::More::is_deeply( \@got, $expected, "analyze_text: $message" );

    @got = $analyzer->analyze_raw($source);
    Test::More::is_deeply( \@got, $expected, "analyze_raw: $message" );

    $batch = $analyzer->analyze_field( { content => $source }, 'content' );
    @got = ();
    while ( my $token = $batch->next ) {
        push @got, $token->get_text;
    }
    Test::More::is_deeply( \@got, $expected, "analyze_field: $message" );
}

1;
