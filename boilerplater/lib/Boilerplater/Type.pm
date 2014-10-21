use strict;
use warnings;

package Boilerplater::Type;
use Boilerplater::Parcel;
use Boilerplater::Util qw( verify_args );
use Scalar::Util qw( blessed );
use Carp;

our %new_PARAMS = (
    const       => undef,
    specifier   => undef,
    indirection => undef,
    parcel      => undef,
    c_string    => undef,
);

sub new {
    my $either = shift;
    my $package = ref($either) || $either;
    confess( __PACKAGE__ . "is an abstract class" )
        if $package eq __PACKAGE__;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, $package;
    if ( defined $self->{parcel} ) {
        if ( !blessed( $self->{parcel} ) ) {
            $self->{parcel}
                = Boilerplater::Parcel->singleton( name => $self->{parcel} );
        }
        confess("Not a Boilerplater::Parcel")
            unless $self->{parcel}->isa('Boilerplater::Parcel');
    }
    return $self;
}

sub get_specifier { shift->{specifier} }
sub get_parcel    { shift->{parcel} }
sub const         { shift->{const} }

sub is_object      {0}
sub is_primitive   {0}
sub is_integer     {0}
sub is_floating    {0}
sub is_void        {0}
sub is_composite   {0}
sub is_string_type {0}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless blessed($other);
    return 0 unless $other->isa(__PACKAGE__);
    return 1;
}

sub to_c { shift->{c_string} }
sub set_c_string { $_[0]->{c_string} = $_[1] }

1;

__END__

__POD__

=head1 NAME

Boilerplater::Type - A variable's type.

=head1 METHODS

=head2 new

    my $type = MyType->new(
        specifier   => 'char',    # default undef
        indirection => undef,     # default 0
        const       => 1,         # default undef
        parcel      => undef,     # default undef
        c_string    => undef,     # default undef
    );

Abstract constructor.

=over

=item *

B<specifier> - The C name for the type, not including any indirection or array
subscripts.  

=item *

B<indirection> - integer indicating level of indirection. Example: the C type
"float**" has a specifier of "float" and indirection 2.

=item *

B<const> - should be true if the type is const.

=item *

B<parcel> - A Boilerplater::Parcel or a parcel name.

=item *

B<c_string> - The C representation of the type.

=back

=head2 equals

    do_stuff() if $type->equals($other);

Returns true if two Boilerplater::Type objects are equivalent.  The default
implementation merely checks that C<$other> is a Boilerplater::Type object, so
it should be overridden in all subclasses.

=head2 to_c

    # Declare variable "foo".
    print $type->to_c . " foo;\n";

Return the C representation of the type.

=head2 set_c_string

Set the C representation of the type.

=head2 get_specifier get_parcel const

Accessors.

=head2 is_object is_primitive is_integer is_floating is_composite is_void

    do_stuff() if $type->is_object;

Shorthand for various $type->isa($package) calls.  

=over

=item * is_object: Boilerplater::Type::Object

=item * is_primitive: Boilerplater::Type::Primitive

=item * is_integer: Boilerplater::Type::Integer

=item * is_floating: Boilerplater::Type::Float

=item * is_void: Boilerplater::Type::Void

=item * is_composite: Boilerplater::Type::Composite

=back

=head2 is_string_type

Returns true if $type represents a Boilerplater type which holds unicode
strings.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

