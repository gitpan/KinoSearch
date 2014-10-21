use strict;
use warnings;

package Boilerplater::Variable;
use base qw( Boilerplater::Symbol );
use Boilerplater::Type;
use Boilerplater::Util qw( verify_args );
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
    confess "micro_sym is required" unless $self->{micro_sym};
    confess "invalid type"
        unless ref( $self->{type} )
            && $self->{type}->isa("Boilerplater::Type");
    return $self;
}

sub get_type  { shift->{type} }
sub micro_sym { shift->{micro_sym} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{micro_sym} eq $other->{micro_sym};
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
    my $name = $self->get_prefix . "$self->{class_cnick}_$self->{micro_sym}";
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

Boilerplater::Variable - A Boilerplater variable.

=head1 DESCRIPTION

A variable, having a L<Type|Boilerplater::Type>, a micro_sym (i.e. name), an
exposure, and optionally, a location in the global namespace hierarchy.

Variable objects which exist only within a local scope, e.g. those within
parameter lists, do not need to know about class.  In contrast, inert class
vars, for example, need to know class information so that they can declare
themselves properly.

=head1 METHODS

=head2 new

    my $var = Boilerplater::Variable->new(
        parcel      => 'Boil',
        type        => $type,    # required
        micro_sym   => 'foo',    # required
        exposure    => undef,    # default: 'local'
        class_name  => "Foo",    # default: undef
        class_cnick => "Foo",    # default: undef
    );

=over

=item * B<type> - A L<Boilerplater::Type>.

=item * B<micro_sym> - The variable's name, without any namespacing prefixes.

=item * B<exposure> - See L<Boilerplater::Symbol>.

=item * B<class_name> - See L<Boilerplater::Symbol>.

=item * B<class_cnick> - See L<Boilerplater::Symbol>.

=back

=head2 local_c

    # e.g. "boil_Foo *foo"
    print $variable->local_c;

Returns a string with the Variable's C type and its C<micro_sym>.

=head2 global_c

    # e.g. "boil_Foo *boil_Foo_foo"
    print $variable->global_c;

Returns a string with the Variable's C type and its fully qualified name
within the global namespace.

=head2 local_declaration

    # e.g. "boil_Foo *foo;"
    print $variable->local_declaration;

Returns C code appropriate for declaring the variable in a local scope, such
as within a C parameter list or struct definition, or as an automatic variable
within a C function.  

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

