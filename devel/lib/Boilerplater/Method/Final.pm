use strict;
use warnings;

package Boilerplater::Method::Final;
use base qw( Boilerplater::Method );
use Carp;
use Boilerplater qw( $prefix $Prefix $PREFIX );

# Create a macro definition that aliases to a function name directly, since
# this method may not be overridden.
sub macro_def {
    my ( $self, $invoker ) = @_;
    my ( $macro_name, $struct_name, $arg_names )
        = @{$self}{qw( macro_name struct_name arg_names )};
    my $full_macro_name = "$Prefix${invoker}_$macro_name";
    my $full_func_name  = $self->get_full_func_name;

    return <<END_STUFF;
#define $full_macro_name($arg_names) \\
    $full_func_name(($prefix$struct_name*)$arg_names)
END_STUFF
}

1;
