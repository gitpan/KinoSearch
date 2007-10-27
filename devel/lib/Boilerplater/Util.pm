use strict;
use warnings;

package Boilerplater::Util;
use base qw( Exporter );
use Carp;
use Boilerplater qw( $prefix $Prefix $PREFIX );

our @EXPORT_OK = qw( slurp_file current strip_c_comments );

# Open a file, read it in, return its contents.
sub slurp_file {
    my $path = shift;
    open( my $fh, '<', $path ) or confess("Can't open '$path': $!");
    local $/;
    return <$fh>;
}

# Given two elements, which may be either scalars or arrays, verify that
# everything in the second group exists and was created later than anything in
# the first group.
sub current {
    my ( $orig, $dest ) = @_;
    my $bubble_time = time;
    $orig = [$orig] unless ref($orig) eq 'ARRAY';
    $dest = [$dest] unless ref($dest) eq 'ARRAY';

    # if a destination file doesn't exist, we're not current
    for (@$dest) {
        return 0 unless -e $_;
    }

    # find the oldest file from the destination group
    for (@$dest) {
        my $candidate = ( stat($_) )[9];
        $bubble_time = $candidate if $candidate < $bubble_time;
    }

    # if any source file is newer than the oldest dest, we're not current
    for (@$orig) {
        my $candidate = ( stat($_) )[9];
        return 0 if $candidate > $bubble_time;
    }

    # current!
    return 1;
}

# Quick 'n' dirty stripping of comments.  Will massacre stuff like comments
# embedded in string literals, so watch out.
sub strip_c_comments {
    my $c_code = shift;
    $c_code =~ s#/\*.*?\*/##gsm;
    return $c_code;
}

1;
