use strict;
use warnings;
use lib 'buildlib';
use Test::More tests => 1;
use File::Spec::Functions qw( catfile catdir );
use File::Path qw( rmtree );

my $search_cgi_orig_path = catfile(qw( sample search.cgi ));
my $indexer_pl_orig_path = catfile(qw( sample indexer.pl ));

# Ensure that all @INC dirs make it into the scripts.  We can't use PERL5LIB
# because search.cgi runs with taint mode and environment vars are tainted.
my $blib_arch = catdir(qw( blib arch ));
my $blib_lib  = catdir(qw( blib lib ));
my @inc_dirs  = map {"use lib '$_';"} ( $blib_arch, $blib_lib, @INC );
my $use_dirs  = join( "\n", @inc_dirs );

for my $filename (qw( search.cgi indexer.pl )) {
    my $orig_path = catfile( 'sample', $filename );
    open( my $fh, '<', $orig_path ) or die "Can't open $orig_path: $!";
    my $content = do { local $/; <$fh> };
    close $fh or die "Close failed: $!";
    $content =~ s/(path_to_index\s+=\s+).*?;/$1'_sample_index';/
        or die "no match";
    my $uscon_source = catdir(qw( sample us_constitution ));
    $content =~ s/(uscon_source\s+=\s+).*?;/$1'$uscon_source';/;
    $content =~ s/^use/$use_dirs;\nuse/m;
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

