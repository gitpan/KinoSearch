#!/usr/bin/perl
use strict;
use warnings;
$|++;

die "Must be run under Perl 5.8.8 (with -DDEBUGGING)" unless $] == 5.008008;
die "Must set PERL_DESTRUCT_LEVEL=2" unless $ENV{PERL_DESTRUCT_LEVEL} == 2;

# grab test file names
opendir( my $t_dir, 't' ) or die "Couldn't opendir 't': $!";
my @t_files = sort grep {/\.t$/} readdir $t_dir;
closedir $t_dir;

# prepare to log output
open( my $log_fh, '>', "valgrind_test.log" ) or die "Can't open file: $!";

# iterate over all test files
for my $t_file (@t_files) {
    my $command
        = "KINO_VALGRIND=1 valgrind --leak-check=full "
        . "--show-reachable=yes "
        . "--suppressions=../devel/conf/p588_valgrind.supp "
        . "$^X -Mblib t/$t_file 2>&1";
    my $output = "\n\n" . ( scalar localtime(time) ) . "\n$command\n";
    $output .= `$command`;
    print $output;
    print $log_fh $output;
}

__END__

__POD__

=head1 NAME

valgrind_test.plx - Run KinoSearch test suite under Valgrind.

=head1 SYNOPSIS

    $ PERL_DESTRUCT_LEVEL=2
    $ export PERL_DESTRUCT_LEVEL
    $ /usr/local/debugperl/bin/perl5.8.8 Build.PL
    $ ./Build code
    $ /usr/local/debugperl/bin/perl5.8.8 ../devel/valgrind_test.plx

=head1 DESCRIPTION

Run the entire KS test suite under valgrind, saving the output to
valgrind_test.log.

Must be run under a debugging Perl version 5.8.8, and with the
PERL_DESTRUCT_LEVEL environment variable set to 2.

=head1 AUTHOR

Marvin Humphrey, E<lt>marvin at rectangular dot comE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2007 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
