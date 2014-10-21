use strict;
use warnings;

package Clownfish::Type::Composite;
use base qw( Clownfish::Type );
use Clownfish::Util qw( verify_args a_isa_b );
use Scalar::Util qw( blessed );
use Carp;

our %new_PARAMS = (
    child       => undef,
    indirection => undef,
    array       => undef,
    nullable    => undef,
);

sub new {
    my ( $either, %args ) = @_;
    my $array    = delete $args{array};
    my $child    = delete $args{child};
    my $nullable = delete $args{nullable};
    confess("Missing required param 'child'")
        unless a_isa_b( $child, "Clownfish::Type" );
    verify_args( \%new_PARAMS, %args ) or confess $@;
    my $self = $either->SUPER::new(%args);
    $self->{child}    = $child;
    $self->{array}    = $array;
    $self->{nullable} = $nullable;

    # Default indirection to 0.
    $self->{indirection} ||= 0;

    # Cache C representation.
    # NOTE: Array postfixes are NOT included.
    my $string = $self->{child}->to_c;
    for ( my $i = 0; $i < $self->{indirection}; $i++ ) {
        $string .= '*';
    }
    $self->set_c_string($string);

    return $self;
}

sub get_specifier { shift->{child}->get_specifier }
sub get_array     { shift->{array} }
sub is_composite  {1}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{indirection} == $other->{indirection};
    return 0 unless $self->{child}->equals( $other->{child} );
    return 0 if ( $self->{array} xor $other->{array} );
    return 0 if ( $self->{array} and $self->{array} ne $other->{array} );
    return 1;
}

1;

__END__

__POD__

=head1 NAME

Clownfish::Type::Composite - A composite type, e.g. Obj**.

=head1 METHODS

=head2 new

    my $type = Clownfish::Type::Composite->new(
        specifier   => 'char',    # required
        indirection => undef,     # default 0
        array       => '[]',      # default undef,
        const       => 1,         # default undef
    );

=over

=item *

B<specifier> - The name of the type, not including any indirection or array
subscripts.  If the type begins with a capital letter, it will be assumed to
be an object type.

=item *

B<indirection> - integer indicating level of indirection. Example: the C type
"float**" has a specifier of "float" and indirection 2.

=item *

B<array> - A string describing an array postfix.  

=item *

B<const> - should be 1 if the type is const.

=back

=head2 get_array

Accessor for the array string.

=head2 get_specifier

Overridden to return the child Type's specifier.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

