#!/usr/bin/perl
use strict;
use warnings;

use File::Find qw( find );
use File::Spec::Functions qw( updir catfile );
use Text::Diff;
use Perl::Tidy;

my $source_dir = shift @ARGV;
die "usage: ./tidyall.plx DIR" unless defined $source_dir;

# grab all perl filepaths
my @paths;
find(
    {   wanted => sub {
            push @paths, $File::Find::name
                if $File::Find::name =~ /\.(pm|t|pl|plx|cgi)$/i;
        },
        no_chdir => 1,
    },
    $source_dir
);

my $rc_filepath = catfile( updir, 'devel', 'kinotidyrc' );
die "can't find kinotidyrc" unless -f $rc_filepath;

for my $path (@paths) {
    # grab orig text
    print "$path\n";
    open( my $fh, '<', $path )
        or die "couldn't open file '$path' for reading: $!";
    my $orig_text = do { local $/; <$fh> };
    close $fh;

    my $tidied = '';
    Perl::Tidy::perltidy(
        source      => \$orig_text,
        destination => \$tidied,
        perltidyrc  => $rc_filepath,
    );

    if ( index( $orig_text, $tidied ) != 0 ) {
        print diff( \$orig_text, \$tidied );
        print "\nModify? ";
        my $response;
        while (1) {
            chomp( $response = <STDIN> );
            if ( $response !~ /^[yn]/ ) {
                print "Please answer y/n: ";
                next;
            }
            last;
        }
        if ( $response =~ /^y/ ) {
            print "Modifying...\n";
            open( my $f, '>', $path )
                or die "couldn't open '$path' for writing: $!";
            print $f $tidied;
            close $f;
        }
    }
}