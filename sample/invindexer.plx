#!/usr/bin/perl
use strict;
use warnings;

### In order for invindexer.plx to work correctly, you must modify
### $source_dir, $path_to_invindex, and possibly $base_url and $lib_path.
###
### $lib_path is the directory which contains USConSchema.pm
###
### $source_dir is the directory containing the US Constitution
### html files.
###
### $path_to_invindex is the future location of the invindex.
###
### $base_url should reflect the location of the us_constitution directory
### when accessed via a web browser.

my ( $lib_path, $source_dir, $path_to_invindex, $base_url );

BEGIN {
    $lib_path         = 'sample';
    $source_dir       = 'sample/us_constitution';
    $path_to_invindex = 'uscon_invindex';
    $base_url         = '/us_constitution';
}

use lib $lib_path;
use File::Spec;
use USConSchema;
use KinoSearch::InvIndexer;

# create a InvIndexer object
my $invindexer = KinoSearch::InvIndexer->new(
    invindex => USConSchema->clobber($path_to_invindex) );

# collect names of source html files
opendir( my $source_dh, $source_dir )
    or die "Couldn't opendir '$source_dir': $!";
my @filenames;
for my $filename ( readdir $source_dh ) {
    next unless $filename =~ /\.html/;
    next if $filename eq 'index.html';
    push @filenames, $filename;
}
closedir $source_dh or die "Couldn't closedir '$source_dir': $!";

# iterate over list of source files
foreach my $filename (@filenames) {
    my $filepath = File::Spec->catfile( $source_dir, $filename );
    print "indexing $filepath\n";
    open( my $fh, '<', $filepath )
        or die "Can't open '$filepath': $!";
    my $raw = do { local $/; <$fh> };

    # build up a document hash
    my $url = "$base_url/$filename";
    my %doc = ( url => $url );
    $raw =~ m#<title>(.*?)</title>#s
        or die "couldn't isolate title in '$filepath'";
    $doc{title} = $1;
    $raw =~ m#<div id="bodytext">(.*?)</div><!--bodytext-->#s
        or die "couldn't isolate bodytext in '$filepath'";
    $doc{content} = $1;
    $doc{content} =~ s/<.*?>/ /gsm;    # quick and dirty tag stripping

    # add the document to the invindex.
    $invindexer->add_doc( \%doc );
}

# finalize the invindex
$invindexer->finish;

