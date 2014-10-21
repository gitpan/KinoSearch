use strict;
use warnings;
use lib 'buildlib';
use Test::More tests => 1;
use File::Spec::Functions qw( catfile catdir );
use File::Path qw( rmtree );

my $search_cgi_orig_path = catfile(qw( sample search.cgi ));
my $indexer_pl_orig_path = catfile(qw( sample indexer.pl ));

for my $filename (qw( search.cgi indexer.pl )) {
    my $orig_path = catfile( 'sample', $filename );
    open( my $fh, '<', $orig_path ) or die "Can't open $orig_path: $!";
    my $content = do { local $/; <$fh> };
    close $fh or die "Close failed: $!";
    $content =~ s/(path_to_index\s+=\s+).*?;/$1'_sample_index';/
        or die "no match";
    my $uscon_source = catdir(qw( sample us_constitution ));
    $content =~ s/(uscon_source\s+=\s+).*?;/$1'$uscon_source';/;
    my $blib_arch = catdir(qw( blib arch ));
    my $blib_lib  = catdir(qw( blib lib ));
    my $blib      = "use lib '$blib_arch';\nuse lib '$blib_lib'\n";
    $content =~ s/^use/$blib;\nuse/m;
    open( $fh, '>', "_$filename" ) or die $!;
    print $fh $content;
    close $fh or die "Close failed: $!";
}

`$^X _indexer.pl 2>&1`;    # Run indexer.  Discard output.
my $html = `$^X -T _search.cgi q=congress`;
$html =~ s#</?strong>##g;    # Delete all strong tags.
$html =~ s/\s+/ /g;          # Collapse all whitespace.
ok( $html =~ /Results 1-10 of 31/, "indexing and search succeeded" );

END {
    unlink('_indexer.pl');
    unlink('_search.cgi');
    rmtree("_sample_index");
}

