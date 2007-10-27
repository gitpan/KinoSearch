#!/usr/bin/perl
use strict;
use warnings;

# Load configuration file.  (Note: change conf.pl location as needed.)
my $conf;
BEGIN { $conf = do "sample/conf.pl" or die "Can't locate conf.pl"; }

use lib @{ $conf->{lib} };
use File::Spec::Functions qw( catfile );
use USConSchema;
use KinoSearch::InvIndexer;

# Create an InvIndexer object.
my $invindexer = KinoSearch::InvIndexer->new(
    invindex => USConSchema->clobber( $conf->{path_to_invindex} ) );

# Collect names of source html files.
opendir( my $source_dh, $conf->{uscon_source} )
    or die "Couldn't opendir '$conf->{uscon_source}': $!";
my @filenames;
for my $filename ( readdir $source_dh ) {
    next unless $filename =~ /\.html/;
    next if $filename eq 'index.html';
    push @filenames, $filename;
}
closedir $source_dh or die "Couldn't closedir '$conf->{uscon_source}': $!";

# Iterate over list of source files.
for my $filename (@filenames) {
    print "Indexing $filename\n";
    my $doc = slurp_and_parse_file($filename);
    $invindexer->add_doc($doc);
}

# Finalize the invindex and print a confirmation message.
$invindexer->finish;
print "Finished.\n";

# Parse an HTML file from our US Constitution collection and return a
# hashref with three keys: title, body, and url.
sub slurp_and_parse_file {
    my $filename = shift;
    my $filepath = catfile( $conf->{uscon_source}, $filename );
    open( my $fh, '<', $filepath )
        or die "Can't open '$filepath': $!";
    my $raw = do { local $/; <$fh> };

    # build up a document hash
    my %doc = ( url => "/us_constitution/$filename" );
    $raw =~ m#<title>(.*?)</title>#s
        or die "couldn't isolate title in '$filepath'";
    $doc{title} = $1;
    $raw =~ m#<div id="bodytext">(.*?)</div><!--bodytext-->#s
        or die "couldn't isolate bodytext in '$filepath'";
    $doc{content} = $1;
    $doc{content} =~ s/<.*?>/ /gsm;    # quick and dirty tag stripping

    return \%doc;
}

