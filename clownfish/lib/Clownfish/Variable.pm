use strict;
use warnings;

package Clownfish::Variable;
use base qw( Clownfish::Symbol );
use Clownfish::Type;
use Clownfish::Util qw( verify_args a_isa_b );
use Carp;

our %new_PARAMS = (
    type        => undef,
    micro_sym   => undef,
    parcel      => undef,
    exposure    => 'local',
    class_name  => undef,
    class_cnick => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = $either->SUPER::new( %new_PARAMS, @_ );
    confess "invalid type"
        unless a_isa_b( $self->{type}, "Clownfish::Type" );
    return $self;
}

sub get_type { shift->{type} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{type}->equals( $other->{type} );
    return $self->SUPER::equals($other);
}

sub local_c {
    my $self      = shift;
    my $type      = $self->{type};
    my $array_str = '';
    if ( $type->is_composite ) {
        $array_str = $type->get_array || '';
    }
    my $type_str = $array_str ? $type->to_c : $type->to_c;
    return "$type_str $self->{micro_sym}$array_str";
}

sub global_c {
    my $self = shift;
    my $type = $self->{type};
    my $name = $self->full_sym;
    my $postfix = '';
    if ( $type->is_composite ) {
        $postfix = $type->get_array || '';
    }
    return $type->to_c . " $name$postfix";
}

sub local_declaration { return shift->local_c . ';' }

1;

__END__

__POD__

=head1 NAME

Clownfish::Variable - A Clownfish variable.

=head1 DESCRIPTION

A variable, having a L<Type|Clownfish::Type>, a micro_sym (i.e. name), an
exposure, and optionally, a location in the global namespace hierarchy.

Variable objects which exist only within a local scope, e.g. those within
parameter lists, do not need to know about class.  In contrast, inert class
vars, for example, need to know class information so that they can declare
themselves properly.

=head1 METHODS

=head2 new

    my $var = Clownfish::Variable->new(
        parcel      => 'Crustacean',
        type        => $int32_t_type,            # required
        micro_sym   => 'average_lifespan',       # required
        exposure    => 'parcel',                 # default: 'local'
        class_name  => "Crustacean::Lobster",    # default: undef
        class_cnick => "Lobster",                # default: undef
    );

=over

=item * B<type> - A L<Clownfish::Type>.

=item * B<micro_sym> - The variable's name, without any namespacing prefixes.

=item * B<exposure> - See L<Clownfish::Symbol>.

=item * B<class_name> - See L<Clownfish::Symbol>.

=item * B<class_cnick> - See L<Clownfish::Symbol>.

=back

=head2 local_c

    # e.g. "int32_t average_lifespan"
    print $variable->local_c;

Returns a string with the Variable's C type and its C<micro_sym>.

=head2 global_c

    # e.g. "int32_t crust_Lobster_average_lifespan"
    print $variable->global_c;

Returns a string with the Variable's C type and its fully qualified name
within the global namespace.

=head2 local_declaration

    # e.g. "int32_t average_lifespan;"
    print $variable->local_declaration;

Returns C code appropriate for declaring the variable in a local scope, such
as within a struct definition, or as an automatic variable within a C
function.  

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

