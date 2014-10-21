use strict;
use warnings;

package Boilerplater::Type::Object;
use base qw( Boilerplater::Type );
use Boilerplater::Parcel;
use Boilerplater::Util qw( verify_args );
use Scalar::Util qw( blessed );
use Carp;

our %new_PARAMS = (
    const       => undef,
    specifier   => undef,
    indirection => 1,
    parcel      => undef,
    incremented => 0,
    decremented => 0,
);

sub new {
    my ( $either, %args ) = @_;
    verify_args( \%new_PARAMS, %args ) or confess $@;
    my $incremented = delete $args{incremented} || 0;
    my $decremented = delete $args{decremented} || 0;
    my $indirection = delete $args{indirection};
    $indirection = 1 unless defined $indirection;
    my $self = $either->SUPER::new(%args);
    $self->{incremented} = $incremented;
    $self->{decremented} = $decremented;
    $self->{indirection} = $indirection;
    $self->{parcel} ||= Boilerplater::Parcel->default_parcel;
    my $prefix = $self->{parcel}->get_prefix;

    # Validate params.
    confess("Indirection must be 1") unless $self->{indirection} == 1;
    confess("Can't be both incremented and decremented")
        if ( $incremented && $decremented );
    confess("Missing required param 'specifier'")
        unless defined $self->{specifier};
    confess("Illegal specifier: '$self->{specifier}")
        unless $self->{specifier}
            =~ /^(?:$prefix)?[A-Z][A-Za-z0-9]*[a-z]+[A-Za-z0-9]*(?!\w)/;

    # Add $prefix if necessary.
    $self->{specifier} = $prefix . $self->{specifier}
        unless $self->{specifier} =~ /^$prefix/;

    # Cache C representation.
    my $string = $self->const ? 'const ' : '';
    $string .= "$self->{specifier}*";
    $self->set_c_string($string);

    # Cache boolean indicating whether this type is a string type.
    $self->{is_string_type} = $self->{specifier} =~ /CharBuf/ ? 1 : 0;

    return $self;
}

sub is_object      {1}
sub incremented    { shift->{incremented} }
sub decremented    { shift->{decremented} }
sub is_string_type { shift->{is_string_type} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{specifier} eq $other->{specifier};
    for (qw( const incremented decremented )) {
        return 0 if ( $self->{$_} xor $other->{$_} );
    }
    return 1;
}

1;

__END__

=head1 NAME

Boilerplater::Type::Boilerplater - An object Type.

=head1 DESCRIPTION

Boilerplater::Type::Object supports object types for all classes.  The type's 
C<specifier> must match the last component of the class name -- i.e. for the
class "Crustacean::Lobster" it must be "Lobster".

=head1 METHODS

=head2 new

    my $type = Boilerplater::Type::Object->new(
        specifier   => "Obj",     # required
        parcel      => "Boil",    # default: the default Parcel.
        const       => undef,     # default undef
        indirection => 1,         # default 1
        incremented => 1,         # default 0
        decremented => 0,         # default 0
    );

=over

=item * B<specifier> - Required.  Must follow the rules for
L<Boilerplater::Class> class name components.

=item * B<parcel> - A L<Boilerplater::Parcel> or a parcel name.

=item * B<const> - Should be true if the Type is const.  Note that this refers
to the object itself and not the pointer.

=item * B<indirection> - Level of indirection.  Must be 1 if supplied.

=item * B<incremented> - Indicate whether the caller must take responsibility
for an added refcount.

=item * B<decremented> - Indicate whether the caller must account for
for a refcount decrement.

=back

The Parcel's prefix will be prepended to the specifier by new().

=head2 incremented

Returns true if the Type is incremented.

=head2 decremented

Returns true if the Type is decremented.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

