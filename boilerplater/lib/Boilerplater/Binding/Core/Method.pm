use strict;
use warnings;

package Boilerplater::Binding::Core::Method;
use Boilerplater::Util qw( a_isa_b );

sub method_def {
    my ( undef,   %args )  = @_;
    my ( $method, $cnick ) = @args{qw( method cnick )};
    confess("Not a Method")
        unless a_isa_b( $method, "Boilerplater::Method" );
    if ( $method->final ) {
        return _final_method_def( $method, $cnick );
    }
    else {
        return _virtual_method_def( $method, $cnick );
    }
}

sub _virtual_method_def {
    my ( $method, $cnick ) = @_;
    my $param_list      = $method->get_param_list;
    my $struct_name     = $method->self_type->get_specifier;
    my $full_macro_name = $method->full_macro_name($cnick);
    my $typedef         = $method->typedef;
    my $offset_var_name = $method->offset_var_name($cnick);
    my $prefix          = $method->get_prefix;
    my $arg_names       = _param_list_to_arg_names($param_list);

    # Prepare the parameter list for the inline function.
    my $params = $param_list->to_c;
    $params =~ s/^.*?\*\s*\w+/const void *vself/
        or confess("no match: $params");

    my $return_type = $method->get_return_type->to_c;
    my $maybe_return = $method->get_return_type->void ? '' : 'return ';

    return <<END_STUFF;
extern size_t $offset_var_name;
static CHY_INLINE $return_type
$full_macro_name($params)
{
    $struct_name *const self = ($struct_name*)vself;
    char *const method_address = (char*)self->vtable + $offset_var_name;
    const $prefix$typedef method = *(($prefix$typedef*)method_address);
    ${maybe_return}method($arg_names);
}
END_STUFF
}

# Create a macro definition that aliases to a function name directly, since
# this method may not be overridden.
sub _final_method_def {
    my ( $method, $cnick ) = @_;
    my $macro_name      = $method->get_macro_name;
    my $self_type       = $method->self_type->to_c;
    my $full_macro_name = $method->get_Prefix . $cnick . "_$macro_name";
    my $full_func_sym   = $method->full_func_sym;
    my $arg_names       = _param_list_to_arg_names( $method->get_param_list );

    return <<END_STUFF;
#define $full_macro_name($arg_names) \\
    $full_func_sym(($self_type)$arg_names)
END_STUFF
}

sub _param_list_to_arg_names {
    my $param_list = shift;
    my $args       = $param_list->get_variables;
    my $arg_names  = join ', ', map { $_->micro_sym } @$args;
    $arg_names =~ s/\s*\w+/self/;
    return $arg_names;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Core::Method - Generate core C code for a method.

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
