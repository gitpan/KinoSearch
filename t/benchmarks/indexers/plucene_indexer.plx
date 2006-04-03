#!/usr/bin/perl
use strict;
use warnings;

use Cwd qw( getcwd );
use Time::HiRes qw( gettimeofday );
use File::Spec::Functions qw( catfile catdir );
use Plucene;
use Plucene::Document;
use Plucene::Document::Field;
use Plucene::Index::Writer;
use Plucene::Analysis::WhitespaceAnalyzer;

my $corpus_dir = 'extracted_corpus';
my $index_dir  = 'plucene_index';

# index all docs unless otherwise spec'd
my $max_to_index = @ARGV ? $ARGV[0] : 0;

# verify that we're running from the right directory;
my $working_dir = getcwd;
die "Must be run from benchmarks/"
    unless $working_dir =~ /benchmarks\W*$/;

# assemble the sorted list of article files
my $filepaths = build_file_list();

# start the clock and build the index
my $start       = Time::HiRes::gettimeofday;
my $num_indexed = build_index( $filepaths, $max_to_index );

# stop the clock and print a report
my $end = Time::HiRes::gettimeofday;
print_report( $start, $end, $num_indexed );

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

# Build an index, stopping at $max docs if $max > 0.
sub build_index {
    my ( $article_filepaths, $max ) = @_;

    my $writer = Plucene::Index::Writer->new( $index_dir,
        Plucene::Analysis::WhitespaceAnalyzer->new(), 1, );

    my $count = 0;
    for my $article_filepath (@$article_filepaths) {
        # the title is the first line, the body is the rest
        open( my $article_fh, '<', $article_filepath )
            or die "Can't open file '$article_filepath'";
        my $title = <$article_fh>;
        my $body  = do { local $/; <$article_fh> };

        # add content to index
        my $doc = Plucene::Document->new;
        $doc->add( Plucene::Document::Field->Text( title => $title ) );
        $doc->add( Plucene::Document::Field->Text( body  => $body ) );
        $writer->add_document($doc);

        # bail if we've reached spec'd number of docs
        $count++;
        last if ( $max and $count == $max );
    }

    # finish index
    $writer->optimize;

    return $count;
}

# Print out stats for this run.
sub print_report {
    my ( $start, $end, $count ) = @_;
    my $total_secs = $end - $start;
    printf( "Plucene $Plucene::VERSION DOCS: %-4d  SECS: %.2f\n",
        $count, $total_secs );
}

