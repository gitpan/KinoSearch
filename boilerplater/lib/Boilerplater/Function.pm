use strict;
use warnings;

package Boilerplater::Function;
use base qw( Boilerplater::Symbol );
use Carp;
use Boilerplater::Util qw( verify_args );
use Boilerplater::Type;
use Boilerplater::ParamList;

my %new_PARAMS = (
    return_type  => undef,
    class_name   => undef,
    class_cnick  => undef,
    param_list   => undef,
    micro_sym    => undef,
    docu_comment => undef,
    parcel       => undef,
    exposure     => 'parcel',
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = $either->SUPER::new( %new_PARAMS, @_ );

    # Validate.
    for (qw( return_type class_name param_list micro_sym )) {
        confess("$_ is mandatory")
            unless defined $self->{$_};
    }
    confess("Invalid micro_sym: '$self->{micro_sym}'")
        unless $self->{micro_sym} =~ /^[a-z0-9_]+$/;
    my $param_list = $self->{param_list};
    confess 'param_list must be a ParamList object'
        unless ref($param_list)
            && $param_list->isa("Boilerplater::ParamList");
    my $return_type = $self->{return_type};
    confess 'return_type must be a Type object'
        unless ref($return_type) && $return_type->isa("Boilerplater::Type");

    # Derive class_cnick if necessary.
    if ( !defined $self->{class_cnick} ) {
        $self->{class_name} =~ /(\w+)$/
            or die "Invalid class name: $self->{class_name}";
        $self->{class_cnick} = $1;
    }

    return $self;
}

# Accessors
sub get_return_type  { shift->{return_type} }
sub micro_sym        { shift->{micro_sym} }
sub get_class_name   { shift->{class_name} }
sub get_class_cnick  { shift->{class_cnick} }
sub get_param_list   { shift->{param_list} }
sub get_docu_comment { shift->{docu_comment} }

# Indicate true if the function is void, false otherwise.
sub void { shift->{return_type}->void }

# Return the fully qualified C symbol for the function.
sub full_func_sym {
    my $self   = shift;
    my $prefix = $self->get_prefix;
    return "$prefix$self->{class_cnick}_$self->{micro_sym}";
}

# Return the pound-define for the function's short name.
sub short_func_sym {
    my $self       = shift;
    my $prefix     = $self->get_prefix;
    my $short_name = "$self->{class_cnick}_$self->{micro_sym}";
    return "  #define $short_name $prefix$short_name\n";
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Function - Metadata describing a function.

=head1 METHODS

=head2 new

    my $type = Boilerplater::Function->new(
        class_name   => 'MyProject::FooFactory',    # required
        class_cnick  => 'FooFact ',                 # required
        param_list   => $param_list,                # required
        micro_sym    => 'count',                    # required
        docu_comment => $docu_comment,              # default: undef
    );

=over

=item *

B<class_name> - The full name of the class in whose namespace the function
resides.

=item *

B<class_cnick> - The nickname of the class.  Used for deriving the global C
symbol for the function.

=item *

B<param_list> - A Boilerplater::ParamList object representing the function's
argument list.

=item *

B<micro_sym> - The lower case name of the function, without any namespacing
prefixes.

=item *

B<docu_comment> - A Boilerplater::DocuComment describing the function.

=back

=head1 COPYRIGHT

Copyright 2006-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
