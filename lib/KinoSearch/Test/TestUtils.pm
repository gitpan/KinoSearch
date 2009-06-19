use strict;
use warnings;

package KinoSearch::Test::TestUtils;
use base qw( Exporter );

our @EXPORT_OK = qw(
    working_dir
    create_working_dir
    remove_working_dir
    create_index
    create_uscon_index
    test_index_loc
    persistent_test_index_loc
    init_test_index_loc
    get_uscon_docs
    utf8_test_strings
    test_analyzer
    doc_ids_from_td_coll
    modulo_set
);

use KinoSearch;
use KinoSearch::Test::TestSchema;

use lib 'sample';
use KinoSearch::Test::USConSchema;

use File::Spec::Functions qw( catdir catfile curdir );
use Encode qw( _utf8_off );
use File::Path qw( rmtree );
use Carp;

my $working_dir = catfile( curdir(), 'kinosearch_test' );

# Return a directory within the system's temp directory where we will put all
# testing scratch files.
sub working_dir {$working_dir}

sub create_working_dir {
    mkdir( $working_dir, 0700 ) or die "Can't mkdir '$working_dir': $!";
}

# Verify that this user owns the working dir, then zap it.  Returns true upon
# success.
sub remove_working_dir {
    return unless -d $working_dir;
    rmtree $working_dir;
    return 1;
}

# Return a location for a test index to be used by a single test file.  If
# the test file crashes it cannot clean up after itself, so we put the cleanup
# routine in a single test file to be run at or near the end of the test
# suite.
sub test_index_loc {
    return catdir( $working_dir, 'test_index' );
}

# Return a location for a test index intended to be shared by multiple test
# files.  It will be cleaned as above.
sub persistent_test_index_loc {
    return catdir( $working_dir, 'persistent_test_index' );
}

# Destroy anything left over in the test_index location, then create the
# directory.  Finally, return the path.
sub init_test_index_loc {
    my $dir = test_index_loc();
    rmtree $dir;
    die "Can't clean up '$dir'" if -e $dir;
    mkdir $dir or die "Can't mkdir '$dir': $!";
    return $dir;
}

# Build a RAM index, using the supplied array of strings as source material.
# The index will have a single field: "content".
sub create_index {
    my $folder  = KinoSearch::Store::RAMFolder->new;
    my $indexer = KinoSearch::Indexer->new(
        index  => $folder,
        schema => KinoSearch::Test::TestSchema->new,
    );
    $indexer->add_doc( { content => $_ } ) for @_;
    $indexer->commit;
    return $folder;
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
        my $category
            = $filename =~ /art/      ? 'article'
            : $filename =~ /amend/    ? 'amendment'
            : $filename =~ /preamble/ ? 'preamble'
            :   confess "Can't derive category for $filename";

        $docs{$filename} = {
            title    => $title,
            bodytext => $bodytext,
            url      => "/us_constitution/$filename",
            category => $category,
        };
    }

    return \%docs;
}

sub create_uscon_index {
    my $folder = KinoSearch::Store::FSFolder->new(
        path => persistent_test_index_loc() );
    my $schema  = KinoSearch::Test::USConSchema->new;
    my $indexer = KinoSearch::Indexer->new(
        schema   => $schema,
        index    => $folder,
        truncate => 1,
        create   => 1,
    );

    $indexer->add_doc( { content => "zz$_" } ) for ( 0 .. 10000 );
    $indexer->commit;
    undef $indexer;

    $indexer = KinoSearch::Indexer->new(
        schema => $schema,
        index  => $folder,
    );
    my $source_docs = get_uscon_docs();
    $indexer->add_doc( { content => $_->{bodytext} } )
        for values %$source_docs;
    $indexer->commit;
    undef $indexer;

    $indexer = KinoSearch::Indexer->new(
        schema => $schema,
        index  => $folder,
    );
    my @chars = ( 'a' .. 'z' );
    for ( 0 .. 1000 ) {
        my $content = '';
        for my $num_words ( 1 .. int( rand(20) ) ) {
            for ( 1 .. ( int( rand(10) ) + 10 ) ) {
                $content .= @chars[ rand(@chars) ];
            }
            $content .= ' ';
        }
        $indexer->add_doc( { content => $content } );
    }
    $indexer->optimize;
    $indexer->commit;
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

# Verify an Analyzer's transform, transform_text, and split methods.
sub test_analyzer {
    my ( $analyzer, $source, $expected, $message ) = @_;

    my $inversion = KinoSearch::Analysis::Inversion->new( text => $source );
    $inversion = $analyzer->transform($inversion);
    my @got;
    while ( my $token = $inversion->next ) {
        push @got, $token->get_text;
    }
    Test::More::is_deeply( \@got, $expected, "analyze: $message" );

    $inversion = $analyzer->transform_text($source);
    @got       = ();
    while ( my $token = $inversion->next ) {
        push @got, $token->get_text;
    }
    Test::More::is_deeply( \@got, $expected, "transform_text: $message" );

    @got = @{ $analyzer->split($source) };
    Test::More::is_deeply( \@got, $expected, "split: $message" );
}

# Extract all doc nums from a SortCollector.  Return two sorted array refs:
# by_score and by_id.
sub doc_ids_from_td_coll {
    my $hc = shift;
    my @by_score;
    my $match_docs = $hc->pop_match_docs;
    my @by_score_then_id = map { $_->get_doc_id }
        sort {
               $b->get_score <=> $a->get_score
            || $a->get_doc_id <=> $b->get_doc_id
        } @$match_docs;
    my @by_id = sort { $a <=> $b } @by_score_then_id;
    return ( \@by_score_then_id, \@by_id );
}

# Use a modulus to generate a set of numbers.
sub modulo_set {
    my ( $interval, $max ) = @_;
    my @out;
    for ( my $doc = $interval; $doc < $max; $doc += $interval ) {
        push @out, $doc;
    }
    return \@out;
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Test::TestUtils

SV*
doc_set()
CODE:
    KOBJ_TO_SV_NOINC( kino_TestUtils_doc_set(), RETVAL );
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

