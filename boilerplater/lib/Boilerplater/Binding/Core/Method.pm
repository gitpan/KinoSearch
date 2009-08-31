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
    my $struct_sym      = $method->self_type->get_specifier;
    my $full_method_sym = $method->full_method_sym($cnick);
    my $full_offset_sym = $method->full_offset_sym($cnick);
    my $typedef         = $method->full_typedef;
    my $prefix          = $method->get_prefix;
    my $arg_names       = $param_list->name_list;
    $arg_names =~ s/\s*\w+/self/;

    # Prepare the parameter list for the inline function.
    my $params = $param_list->to_c;
    $params =~ s/^.*?\*\s*\w+/const void *vself/
        or confess("no match: $params");

    my $return_type = $method->get_return_type->to_c;
    my $maybe_return = $method->get_return_type->is_void ? '' : 'return ';

    return <<END_STUFF;
extern size_t $full_offset_sym;
static CHY_INLINE $return_type
$full_method_sym($params)
{
    $struct_sym *const self = ($struct_sym*)vself;
    char *const method_address = *(char**)self + $full_offset_sym;
    const $typedef method = *(($typedef*)method_address);
    ${maybe_return}method($arg_names);
}
END_STUFF
}

# Create a macro definition that aliases to a function name directly, since
# this method may not be overridden.
sub _final_method_def {
    my ( $method, $cnick ) = @_;
    my $macro_sym       = $method->get_macro_sym;
    my $self_type       = $method->self_type->to_c;
    my $full_method_sym = $method->full_method_sym($cnick);
    my $full_func_sym   = $method->full_func_sym;
    my $arg_names       = $method->get_param_list->name_list;

    return <<END_STUFF;
#define $full_method_sym($arg_names) \\
    $full_func_sym(($self_type)$arg_names)
END_STUFF
}

sub typedef_dec {
    my ( undef, $method ) = @_;
    my $prefix      = $method->get_prefix;
    my $params      = $method->get_param_list->to_c;
    my $return_type = $method->get_return_type->to_c;
    my $typedef     = $method->full_typedef;
    return <<END_STUFF;
typedef $return_type
(*$typedef)($params);
END_STUFF
}

sub callback_dec {
    my ( undef, $method ) = @_;
    my $callback_sym = $method->full_callback_sym;
    return qq|extern kino_Callback $callback_sym;\n|;
}

sub callback_obj_def {
    my ( undef, %args ) = @_;
    my $method       = $args{method};
    my $offset       = $args{offset};
    my $macro_sym    = $method->get_macro_sym;
    my $len          = length($macro_sym);
    my $func_sym     = $method->full_override_sym;
    my $callback_sym = $method->full_callback_sym;
    return qq|kino_Callback $callback_sym = |
        . qq|{"$macro_sym", $len, (boil_method_t)$func_sym, $offset};\n|;
}

sub callback_def {
    my ( undef, $method ) = @_;
    my $return_type = $method->get_return_type;
    return
          $return_type->is_void   ? _void_callback_def($method)
        : $return_type->is_object ? _obj_callback_def($method)
        :                           _primitive_callback_def($method);
}

sub _callback_params {
    my $method     = shift;
    my $micro_sym  = $method->micro_sym;
    my $param_list = $method->get_param_list;
    my $num_params = $param_list->num_vars - 1;
    my $arg_vars   = $param_list->get_variables;
    my $PREFIX     = $method->get_PREFIX;
    my @params;
    for my $var ( @$arg_vars[ 1 .. $#$arg_vars ] ) {
        my $name = $var->micro_sym;
        my $type = $var->get_type;
        my $param
            = $type->is_string_type ? qq|${PREFIX}ARG_STR("$name", $name)|
            : $type->is_object      ? qq|${PREFIX}ARG_OBJ("$name", $name)|
            : $type->is_integer     ? qq|${PREFIX}ARG_I32("$name", $name)|
            :                         qq|${PREFIX}ARG_F("$name", $name)|;
        push @params, $param;
    }
    return join( ', ', 'self', qq|"$micro_sym"|, $num_params, @params );
}

sub _void_callback_def {
    my $method          = shift;
    my $override_sym    = $method->full_override_sym;
    my $callback_params = _callback_params($method);
    my $params          = $method->get_param_list->to_c;
    my $prefix          = $method->get_prefix;
    return <<END_CALLBACK_DEF;
void
$override_sym($params)
{
    ${prefix}Host_callback($callback_params);
}
END_CALLBACK_DEF
}

sub _primitive_callback_def {
    my $method          = shift;
    my $override_sym    = $method->full_override_sym;
    my $callback_params = _callback_params($method);
    my $params          = $method->get_param_list->to_c;
    my $return_type     = $method->get_return_type;
    my $return_type_str = $return_type->to_c;
    my $prefix          = $method->get_prefix;
    my $nat_func
        = $return_type->is_floating ? "${prefix}Host_callback_f"
        : $return_type->is_integer  ? "${prefix}Host_callback_i"
        : $return_type_str eq 'void*' ? "${prefix}Host_callback_nat"
        :   confess("unrecognized type: $return_type_str");
    return <<END_CALLBACK_DEF;
$return_type_str
$override_sym($params)
{
    return ($return_type_str)$nat_func($callback_params);
}
END_CALLBACK_DEF
}

sub _obj_callback_def {
    my $method          = shift;
    my $override_sym    = $method->full_override_sym;
    my $callback_params = _callback_params($method);
    my $params          = $method->get_param_list->to_c;
    my $return_type     = $method->get_return_type;
    my $return_type_str = $return_type->to_c;
    my $prefix          = $method->get_prefix;
    my $PREFIX          = $method->get_PREFIX;
    my $cb_func_name
        = $return_type->is_string_type
        ? "${prefix}Host_callback_str"
        : "${prefix}Host_callback_obj";

    if ( $return_type->incremented ) {
        return <<END_CALLBACK_DEF;
$return_type_str
$override_sym($params)
{
    return ($return_type_str)$cb_func_name($callback_params);
}
END_CALLBACK_DEF
    }
    else {
        return <<END_CALLBACK_DEF;
$return_type_str
$override_sym($params)
{
    $return_type_str retval = ($return_type_str)$cb_func_name($callback_params);
    ${PREFIX}DECREF(retval);
    return retval;
}
END_CALLBACK_DEF
    }
}

sub abstract_method_def {
    my ( undef, $method ) = @_;
    my $params          = $method->get_param_list->to_c;
    my $full_func_sym   = $method->full_func_sym;
    my $vtable          = uc( $method->self_type->get_specifier );
    my $return_type     = $method->get_return_type;
    my $return_type_str = $return_type->to_c;
    my $prefix          = $method->get_prefix;
    my $Prefix          = $method->get_Prefix;
    my $macro_sym       = $method->get_macro_sym;

    # Build list of unused params and create an unreachable return statement
    # if necessary, in order to thwart compiler warnings.
    my $param_vars = $method->get_param_list->get_variables;
    my $unused     = "";
    for ( my $i = 1; $i < @$param_vars; $i++ ) {
        my $var_name = $param_vars->[$i]->micro_sym;
        $unused .= "\n    CHY_UNUSED_VAR($var_name);";
    }
    my $ret_statement = '';
    if ( !$return_type->is_void ) {
        $ret_statement = "\n    CHY_UNREACHABLE_RETURN($return_type_str);";
    }

    return <<END_ABSTRACT_DEF;
$return_type_str
$full_func_sym($params)
{
    kino_CharBuf *klass = self ? Kino_Obj_Get_Class_Name(self) : $vtable->name;$unused
    BOIL_THROW(BOIL_ERR, "Abstract method '$macro_sym' not defined by %o", klass);$ret_statement
}
END_ABSTRACT_DEF
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Core::Method - Generate core C code for a method.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
