#!/usr/bin/perl
use strict;
use warnings;

use lib 'indexers';

use Getopt::Long;
use Cwd qw( getcwd );
use BenchmarkingIndexer;

# verify that we're running from the right directory;
my $working_dir = getcwd;
die "Must be run from benchmarks/"
    unless $working_dir =~ /benchmarks\W*$/;

# index all docs and run one iter unless otherwise spec'd
my ( $num_reps, $max_to_index, $increment, $store, $build_index );
GetOptions( 
    'reps=s' => \$num_reps, 
    'docs=s' => \$max_to_index,
    'increment=s' => \$increment,
    'store=s'  => \$store,
    'build_index=s' => \$build_index,
);
$num_reps  = 1 unless defined $num_reps;

my $bencher = BenchmarkingIndexer::Plucene->new(
    docs      => $max_to_index,
    increment => $increment,
    store     => $store,
);

if ($build_index) {
    my ( $count, $secs ) = $bencher->build_index;
    print "docs: $count elapsed: $secs\n";
    exit;
}
else {
    $bencher->start_report;

    my @times;
    for my $rep ( 1 .. $num_reps ) {
        # spawn an index-building child process
        my $command = "$^X ";
        # try to figure out if this program was called with -Mblib
        for (@INC) {
            next unless /\bblib\b/;
            # propagate -Mblib to the child
            $command .= "-Mblib ";
            last;
        }
        $command .= "$0 --build_index=1 ";
        $command .= "--docs=$max_to_index " if $max_to_index;
        $command .= "--store=$store " if $store;
        $command .= "--increment=$increment " if $increment;
        my $output = `$command`;

        # extract elapsed time from the output of the child
        $output =~ /^docs: (\d+) elapsed: ([\d.]+)/ 
            or die "no match: '$output'";
        my $docs = $1;
        my $secs = $2;
        push @times, $secs;

        $bencher->print_interim_report( 
            rep => $rep, 
            secs => $secs,
            count => $docs,
        );
    }

    $bencher->print_final_report(\@times);
}

