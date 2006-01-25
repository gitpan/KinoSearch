#!/usr/bin/perl
use strict;
use warnings;

use File::Find qw( find );
use Text::Diff qw( diff );
use Getopt::Long qw( GetOptions );

# parse command line
my ($regex, $dir);
GetOptions( 'regex=s' => \$regex, 'dir=s' => \$dir );
die qq#usage: ./recursive_edit.plx --regex=REGEX --dir=DIR#
  unless ( defined $regex and defined $dir );

# walk file hierarchy, applying edit to each file
find(
    {
        wanted   => \&maybe_edit,
        no_chdir => 1,
    },

    $dir,
);

sub maybe_edit {
    return unless $File::Find::name =~ /\.(pm|pod)$/;
    return if $File::Find::name =~ /\.svn/;
    my $orig = my $edited = do {
        open( my $fh, "<", $File::Find::name)
            or die "Couldn't open '$File::Find::name' for reading: $!";
        local $/;
        <$fh>;
    };

    # apply the regex to the content
    eval '$edited =~ ' . $regex . ';';
    die $@ if $@;

    # confirm that the change worked as intended.
	return if $edited eq $orig;
    my $diff = diff( \$orig, \$edited );
	print "\nFILE: $File::Find::name\n";
    print "DIFF:\n$diff\nApply? ";
    my $response = <STDIN>;
    return unless $response =~ /^y/i;

    print "Applying edit...\n";
    open( my $fh, ">", $File::Find::name )
        or die "Couldn't open '$File::Find::name' for writing: $!";
    print $fh $edited;
}



