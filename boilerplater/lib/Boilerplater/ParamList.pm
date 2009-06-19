use strict;
use warnings;

package Boilerplater::ParamList;
use Boilerplater::Variable;
use Boilerplater::Util qw( verify_args );
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
            unless ref($var) && $var->isa("Boilerplater::Variable");
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
    my $string = join( ', ', map { $_->to_c } @{ $self->{variables} } );
    $string .= ", ..." if $self->{variadic};
    return $string;
}

sub name_list {
    my $self = shift;
    return join( ', ', map { $_->micro_sym } @{ $self->{variables} } );
}

1;

