#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Cwd qw( getcwd );
use Time::HiRes qw( gettimeofday );
use File::Spec::Functions qw( catfile catdir );
use POSIX qw( uname );
use Config;
use KinoSearch::InvIndexer;
use KinoSearch::Analysis::Tokenizer;

# verify that we're running from the right directory;
my $working_dir = getcwd;
die "Must be run from benchmarks/"
    unless $working_dir =~ /benchmarks\W*$/;

my $corpus_dir = 'extracted_corpus';
my $index_dir  = 'kinosearch_index';
my $filepaths  = build_file_list();

# index all docs and run one iter unless otherwise spec'd
my ( $num_reps, $max_to_index, $increment);
GetOptions( 
    'reps=s' => \$num_reps, 
    'docs=s' => \$max_to_index,
    'increment=s' => \$increment,
);
$max_to_index = @$filepaths unless defined $max_to_index;
$num_reps     = 1 unless defined $num_reps;
$increment    = $max_to_index + 1 unless defined $increment;

# start the output
print '-' x 60 . "\n";

my @times;
for my $rep ( 1 .. $num_reps ) {
    # start the clock and build the index
    my $start       = Time::HiRes::gettimeofday;
    my $num_indexed = build_index( $filepaths, $max_to_index );

    # stop the clock and print a report
    my $end = Time::HiRes::gettimeofday;
    my $secs = $end - $start;
    print_interim_report( $rep, $secs, $num_indexed );
    push @times, $secs;
}

print_final_report( \@times );

# Return a lexically sorted list of all article files from all subdirs.
sub build_file_list {
    my @article_filepaths;
    opendir CORPUS_DIR, $corpus_dir or die "Can't opendir '$corpus_dir': $!";
    my @article_dir_names = grep {/articles/} readdir CORPUS_DIR;
    for my $article_dir_name (@article_dir_names) {
        my $article_dir = catdir( $corpus_dir, $article_dir_name );
        opendir ARTICLE_DIR, $article_dir
            or die "Can't opendir '$article_dir': $!";
        push @article_filepaths, map { catfile( $article_dir, $_ ) }
            grep {m/^article\d+\.txt$/} readdir ARTICLE_DIR;
    }
    @article_filepaths = sort @article_filepaths;
    return \@article_filepaths;
}

my $indexer_last_initialized = 0;
sub init_invindexer {
    my $count = shift;
    my $create = $count ? 0 : 1;

    $indexer_last_initialized = $count;
    # spec out the invindexer
    my $analyzer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/, );
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $index_dir,
        create   => $create,
        analyzer => $analyzer,
    );
    $invindexer->spec_field(
        name       => 'body',
        #stored     => 0,
        #vectorized => 0,
    );
    $invindexer->spec_field(
        name       => 'title',
        vectorized => 0,
    );

    return $invindexer;
}

# Build an index, stopping at $max docs if $max > 0.
sub build_index {
    my ( $article_filepaths, $max ) = @_;

    my $invindexer = init_invindexer(0);

    my $count = 0;
    while ($count < $max) {
        for my $article_filepath (@$article_filepaths) {
            # the title is the first line, the body is the rest
            open( my $article_fh, '<', $article_filepath )
                or die "Can't open file '$article_filepath'";
            my $title = <$article_fh>;
            my $body  = do { local $/; <$article_fh> };

            # add content to index
            my $doc = $invindexer->new_doc;
            $doc->set_value( title => $title );
            $doc->set_value( body  => $body );
            $invindexer->add_doc($doc);

            # bail if we've reached spec'd number of docs
            $count++;
            last if $count >= $max;
            if ( $count % $increment == 0 and $count ) {
                $invindexer->finish;
                undef $invindexer;
                $invindexer = init_invindexer($count);
            }
        }
    }

    # finish index
    $invindexer->finish( optimize => 1 );
    #$invindexer->finish( optimize => 1 );

    return $count;
}

# Print out stats for this run.
sub print_interim_report {
    my ( $rep, $secs, $count ) = @_;
    printf( "%-3d  Secs: %.2f  Docs: %-4d\n", $rep, $secs, $count );
}

# Print out aggregate stats
sub print_final_report {
    my $times = shift;

    # produce mean and truncated mean
    my @sorted_times = sort @$times;
    my $num_to_chop = int( @sorted_times >> 2 );
    my $mean = 0; 
    my $trunc_mean = 0;
    my $num_kept = 0;
    for ( my $i = 0; $i < @sorted_times; $i++ ) {
        $mean += $sorted_times[$i];
        # discard fastest 25% and slowest 25% of runs
        next if $i < $num_to_chop;
        next if $i > ( $#sorted_times - $num_to_chop );
        $trunc_mean += $sorted_times[$i];
        $num_kept++;
    }
    $mean /= @sorted_times;
    $trunc_mean /= $num_kept;
    my $num_discarded = @sorted_times - $num_kept;
    $mean = sprintf("%.2f", $mean);
    $trunc_mean = sprintf("%.2f", $trunc_mean);

    # get some info about the system
    my $thread_support = $Config{usethreads} ? "yes" : "no";
    my @uname_info = (uname)[0, 2, 4];
    
    print <<END_REPORT;
------------------------------------------------------------
KinoSearch $KinoSearch::VERSION 
Perl $Config{version}
Thread support: $thread_support
@uname_info
Mean: $mean secs 
Truncated mean ($num_kept kept, $num_discarded discarded): $trunc_mean secs
------------------------------------------------------------
END_REPORT
}

