use strict;
use warnings;

my $test_file = shift @ARGV;

my $i = 0;
while (1) {
    $i++;
    print "$i...\n";
    my $retval = system( $^X, "-Mblib ", $test_file, $i );
    if ($retval) {
        print "Test failed at $i\n";
        exit;
    }
}