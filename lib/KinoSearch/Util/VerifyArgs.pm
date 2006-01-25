package KinoSearch::Util::VerifyArgs;
use strict;
use warnings;

use Scalar::Util qw( blessed );
use Carp;

use base qw( Exporter );

our @EXPORT_OK = qw( verify_args a_isa_b );

# Verify that named parameters exist in a defaults hash.
sub verify_args {
    my $defaults = shift;    # leave the rest of @_ intact

    # verify that args came in pairs
    if ( @_ % 2 ) {
        my ( $package, $filename, $line ) = caller(1);
        die "Parameter error: odd number of args at $filename line $line\n";
    }

    # verify keys, ignore values
    while (@_) {
        my ( $var, undef ) = ( shift, shift );
        next if exists $defaults->{$var};
        my ( $package, $filename, $line ) = caller(1);
        die "Invalid parameter: '$var' at $filename line $line\n";
    }
}

=begin comment

a_isa_b serves the same purpose as the isa method from UNIVERSAL, only it is
called as a function rather than a method.

    # safer than $foo->isa($class), which crashes if $foo isn't blessed
    my $confirm = a_isa_b( $foo, $class );

=end comment
=cut

sub a_isa_b {
    my ( $item, $class_name ) = @_;
    return 0 unless blessed($item);
    return $item->isa($class_name);
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Util::VerifyArgs - some validation functions

=head1 DESCRIPTION

Provide some utility functions under the general heading of "verification".

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut
