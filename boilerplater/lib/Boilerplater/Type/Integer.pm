use strict;
use warnings;

package Boilerplater::Type::Integer;
use base qw( Boilerplater::Type::Primitive );
use Boilerplater::Util qw( verify_args );
use Carp;

our %new_PARAMS = (
    const     => undef,
    specifier => undef,
);

our %specifiers = (
    bool_t => undef,
    i8_t   => undef,
    i16_t  => undef,
    i32_t  => undef,
    i64_t  => undef,
    u8_t   => undef,
    u16_t  => undef,
    u32_t  => undef,
    u64_t  => undef,
    char   => undef,
    int    => undef,
    short  => undef,
    long   => undef,
    size_t => undef,
);

sub new {
    my ( $either, %args ) = @_;
    verify_args( \%new_PARAMS, %args ) or confess $@;
    confess("Unknown specifier: '$args{specifier}'")
        unless exists $specifiers{ $args{specifier} };

    # Cache the C representation of this type.
    my $c_string = $args{const} ? 'const ' : '';
    if ( $args{specifier} =~ /^(?:[iu]\d+|bool)_t$/ ) {
        $c_string .= "chy_";
    }
    $c_string .= $args{specifier};

    return $either->SUPER::new( %args, c_string => $c_string );
}

sub is_integer {1}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Type::Integer - A primitive Type representing an integer.

=head1 DESCRIPTION

Boilerplater::Type::Integer holds integer types of various widths and various
styles.  A few standard C integer types are supported:

    char
    short
    int
    long
    size_t

Many others are not: the types from "inttypes.h", "signed" or "unsigned"
anything, "long long", "ptrdiff_t", "off_t", etc.  

Instead, the following Charmonizer typedefs are supported:

    bool_t
    i8_t
    i16_t
    i32_t
    i64_t
    u8_t
    u16_t
    u32_t
    u64_t

=head1 METHODS

=head2 new

    my $type = Boilerplater::Type::Integer->new(
        const     => 1,       # default: undef
        specifier => 'char',  # required
    );

=over

=item * B<const> - Should be true if the type is const.

=item * B<specifier> - Must match one of the supported types.

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

