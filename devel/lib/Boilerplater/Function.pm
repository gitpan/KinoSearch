use strict;
use warnings;

package Function;
use Carp;
use Boilerplater qw( $prefix $Prefix $PREFIX );

sub new {
    my $either     = shift;
    my $perl_class = ref($either) || $either;
    my $self       = bless {
        return_type => undef,
        class_name  => undef,
        class_nick  => undef,
        struct_name => undef,
        arg_list    => undef,
        micro_name  => undef,
        @_,
    }, $perl_class;
    return $self;
}

# Accessors
sub get_return_type { shift->{return_type} }
sub get_micro_name  { shift->{micro_name} }
sub get_class_nick  { shift->{class_nick} }
sub get_arg_list    { shift->{arg_list} }

# Reconstruct the full name of the function.
sub get_full_func_name {
    my $self = shift;
    return "$prefix$self->{class_nick}_$self->{micro_name}";
}

# Return the function's short name.
sub short_func {
    my $self       = shift;
    my $short_name = "$self->{class_nick}_$self->{micro_name}";
    return "  #define $short_name $prefix$short_name\n";
}

1;
