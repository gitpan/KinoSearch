use strict;
use warnings;

package Clownfish::ParamList;
use Clownfish::Variable;
use Clownfish::Util qw( verify_args );
use Carp;

our %new_PARAMS = (
    variables      => undef,
    initial_values => undef,
    variadic       => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, ref($either) || $either;

    # Validate variables.
    confess "variables must be an arrayref"
        unless ref( $self->{variables} ) eq 'ARRAY';
    for my $var ( @{ $self->{variables} } ) {
        confess "invalid variable: '$var'"
            unless ref($var) && $var->isa("Clownfish::Variable");
    }

    # Validate or init initial_values.
    if ( defined $self->{initial_values} ) {
        confess "variables must be an arrayref"
            unless ref( $self->{variables} ) eq 'ARRAY';
        my $num_init = scalar @{ $self->{initial_values} };
        my $num_vars = $self->num_vars;
        confess("mismatch of num vars and init values: $num_vars $num_init")
            unless $num_init == $num_vars;
    }
    else {
        my @initial_values;
        $#initial_values = $#{ $self->{variables} };
        $self->{initial_values} = \@initial_values;
    }

    return $self;
}

sub get_variables      { shift->{variables} }
sub get_initial_values { shift->{initial_values} }
sub variadic           { shift->{variadic} }
sub num_vars           { scalar @{ shift->{variables} } }

sub to_c {
    my $self = shift;
    my $string = join( ', ', map { $_->local_c } @{ $self->{variables} } );
    $string .= ", ..." if $self->{variadic};
    return $string;
}

sub name_list {
    my $self = shift;
    return join( ', ', map { $_->micro_sym } @{ $self->{variables} } );
}

1;

__END__

__POD__

=head1 NAME

Clownfish::ParamList - parameter list.

=head1 DESCRIPTION

=head1 METHODS

=head2 new

    my $type = Clownfish::ParamList->new(
        variables      => \@vars,    # required
        initial_values => \@vals,    # default: undef
        variadic       => 1,         # default: false
    );

=over

=item * B<variables> - An array where each element is a
L<Clownfish::Variable>. 

=item * B<initial_values> - If supplied, an array of default values, one for
each variable.

=item * B<variadic> - Should be true if the function is variadic.

=back

=head2 get_variables get_initial_values variadic

Accessors. 

=head2 num_vars

Return the number of variables in the ParamList, including "self" for methods.

=head2 to_c

    # Prints "Obj* self, Foo* foo, Bar* bar".
    print $param_list->to_c;

Return a list of the variable's types and names, joined by commas.

=head2 name_list

    # Prints "self, foo, bar".
    print $param_list->name_list;

Return the variable's names, joined by commas.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

