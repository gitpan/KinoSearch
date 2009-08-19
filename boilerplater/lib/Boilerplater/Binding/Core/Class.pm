use strict;
use warnings;

package Boilerplater::Binding::Core::Class;
use Boilerplater::Util qw( a_isa_b verify_args );
use Boilerplater::Binding::Core::Method;
use Boilerplater::Binding::Core::Function;
use File::Spec::Functions qw( catfile );

our %new_PARAMS = ( client => undef, );

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, ref($either) || $either;

    my $client = $self->{client};
    confess("Not a Boilerplater::Class")
        unless a_isa_b( $client, "Boilerplater::Class" );

    # Cache some vars.
    $self->{class_name}   = $client->get_class_name;
    $self->{struct_name}  = $client->get_struct_name;
    $self->{cnick}        = $client->get_cnick;
    $self->{source_class} = $client->get_source_class;

    return $self;
}

sub get_prefix { shift->{client}->get_prefix }
sub get_Prefix { shift->{client}->get_Prefix }
sub get_PREFIX { shift->{client}->get_PREFIX }

#     # /path/to/Foo/Bar.c, if source class is Foo::Bar.
#     my $path = $class->file_path( '/path/to', '.c' );
#
# Provide an OS-specific path for a file relating to this class could be
# found, by joining together the components of the "source class" name.
sub file_path {
    my ( $self, $base_dir, $ext ) = @_;
    my @components = split( '::', $self->{source_class} );
    unshift @components, $base_dir
        if defined $base_dir;
    $components[-1] .= $ext;
    return catfile(@components);
}

# Return a relative path to a C header file, appropriately formatted for a
# pound-include directive.
sub include_h {
    my $self = shift;
    my @components = split( '::', $self->{source_class} );
    $components[-1] .= '.h';
    return join( '/', @components );
}

# The name of the global VTable object for this class.
sub vtable_var { uc( shift->{struct_name} ) }

# The name of the global Callbacks list for this class.
sub callbacks_var { shift->vtable_var . '_CALLBACKS' }

# The name of the global class name var for this class.
sub name_var { shift->vtable_var . '_CLASS_NAME' }

sub name_var_definition {
    my $self           = shift;
    my $prefix         = $self->get_prefix;
    my $PREFIX         = $self->get_PREFIX;
    my $full_var_name  = $PREFIX . $self->name_var;
    my $class_name_len = length( $self->{class_name} );
    return <<END_STUFF;
${prefix}ZombieCharBuf $full_var_name = {
    ${PREFIX}ZOMBIECHARBUF,
    {1}, /* ref.count */
    "$self->{class_name}",
    $class_name_len,
    0
};

END_STUFF
}

# The C type specifier for this class's vtable.  Each vtable needs to have its
# own type because each has a variable number of methods at the end of the
# struct, and it's not possible to initialize a static struct with a flexible
# array at the end under C89.
sub vtable_type { shift->vtable_var . '_VT' }

# Define the vtable.
sub vtable_definition {
    my $self       = shift;
    my $client     = $self->{client};
    my $parent     = $client->get_parent;
    my @methods    = $client->get_methods;
    my $name_var   = $self->name_var;
    my $vtable_var = $self->vtable_var;
    my $vt         = $vtable_var . "_vt";
    my $vt_type    = $self->vtable_type;
    my $cnick      = $self->{cnick};
    my $prefix     = $self->get_prefix;
    my $PREFIX     = $self->get_PREFIX;

    # Create a pointer to the parent class's vtable.
    my $parent_ref
        = defined $parent
        ? "$PREFIX" . $parent->vtable_var
        : "NULL";    # No parent, e.g. Obj or inert classes.

    # Spec functions which implement the methods, casting to quiet compiler.
    my @implementing_funcs
        = map { "(boil_method_t)" . $_->full_func_sym } @methods;
    my $method_string = join( ",\n        ", @implementing_funcs );
    my $num_methods = scalar @implementing_funcs;

    return <<END_VTABLE

$PREFIX$vt_type $PREFIX$vt = {
    ${PREFIX}VTABLE, /* vtable vtable */
    {1}, /* ref.count */
    $parent_ref, /* parent */
    (${prefix}CharBuf*)&${PREFIX}$name_var,
    ${PREFIX}VTABLE_F_IMMORTAL, /* flags */
    NULL, /* "void *x" member reserved for future use */
    sizeof(${prefix}$self->{struct_name}), /* obj_alloc_size */
    offsetof(${prefix}VTable, methods) 
        + $num_methods * sizeof(boil_method_t), /* vt_alloc_size */
    (${prefix}Callback**)&${PREFIX}${vtable_var}_CALLBACKS,  /* callbacks */
    {
        $method_string
    }
};

END_VTABLE
}

# Create the definition for the instantiable struct object.
sub struct_definition {
    my $self                = shift;
    my $prefix              = $self->get_prefix;
    my $member_declarations = join( "\n    ",
        map { $_->local_declaration } $self->{client}->get_member_vars );

    return <<END_STRUCT
struct $prefix$self->{struct_name} {
    $member_declarations
};
END_STRUCT
}

# Return C representation of class.
sub to_c_header {
    my $self = shift;
    my ( $client, $cnick, $struct_name )
        = @{$self}{qw( client cnick struct_name )};
    my @functions     = $client->get_functions;
    my @methods       = $client->get_methods;
    my @novel_methods = $client->novel_methods;
    my @inert_vars    = $client->get_inert_vars;
    my $vtable_var    = $self->vtable_var;
    my $struct_def    = $self->struct_definition;
    my $prefix        = $self->get_prefix;
    my $PREFIX        = $self->get_PREFIX;

    # If class inherits from something, include the parent class's header.
    my $parent_include = "";
    if ( my $parent = $client->get_parent ) {
        $parent_include = $parent->include_h;
        $parent_include = qq|#include "$parent_include"|;
    }

    # Add a C function definition for each method and each function.
    my $sub_declarations = "";
    for my $sub ( @functions, @novel_methods ) {
        $sub_declarations
            .= Boilerplater::Binding::Core::Function->func_declaration($sub)
            . "\n\n";
    }

    # Declare class (a.k.a. "inert") variables.
    my $inert_vars = "";
    for my $inert_var ( $client->get_inert_vars ) {
        $inert_vars .= "extern " . $inert_var->global_c . ";\n";
    }

    # Declare typedefs for novel methods, to ease casting.
    my $method_typedefs = '';
    for my $method (@novel_methods) {
        $method_typedefs .= $method->typedef_dec . "\n";
    }

    # Define method invocation syntax.
    my $method_defs = '';
    for my $method (@methods) {
        $method_defs .= Boilerplater::Binding::Core::Method->method_def(
            method => $method,
            cnick  => $cnick,
        ) . "\n";
    }

    # Declare the virtual table singleton object.
    my $vt_type       = $PREFIX . $self->vtable_type;
    my $vt            = "extern struct $vt_type $PREFIX${vtable_var}_vt;";
    my $vtable_object = "#define $PREFIX$vtable_var "
        . "((${prefix}VTable*)&$PREFIX${vtable_var}_vt)";
    my $num_methods = scalar @methods;

    # Declare Callback objects.
    my $callback_declarations = "";
    for my $method (@novel_methods) {
        next unless $method->public || $method->abstract;
        $callback_declarations .= $method->callback_dec . "\n";
    }

    # Define short names.
    my $short_names = '';
    for my $function (@functions) {
        $short_names .= $function->short_func_sym;
    }
    for my $inert_var (@inert_vars) {
        my $short_name = "$self->{cnick}_" . $inert_var->micro_sym;
        $short_names .= "  #define $short_name $prefix$short_name\n";
    }
    if ( !$client->inert ) {
        for my $method (@novel_methods) {
            $short_names .= $method->short_typedef
                unless $method->isa("Boilerplater::Method::Overridden");
            $short_names .= $method->short_func_sym;
        }
        for my $method (@methods) {
            $short_names .= $method->short_method_macro($cnick);
        }
    }

    # Make the spacing in the file a little more elegant.
    s/\s+$// for ( $method_typedefs, $method_defs, $short_names );

    # Inert classes only output inert functions and member vars.
    if ( $client->inert ) {
        return <<END_INERT
#include "charmony.h"
#include "boil.h"
$parent_include

$inert_vars

$sub_declarations

#ifdef ${PREFIX}USE_SHORT_NAMES
$short_names
#endif /* ${PREFIX}USE_SHORT_NAMES */

END_INERT
    }

    # Instantiable classes get everything.
    return <<END_STUFF;

#include "charmony.h"
#include "boil.h"
$parent_include

$struct_def

$inert_vars

$sub_declarations
$callback_declarations

$method_typedefs

$method_defs

typedef struct $vt_type {
    ${prefix}VTable *vtable;
    boil_ref_t ref;
    ${prefix}VTable *parent;
    ${prefix}CharBuf *name;
    chy_u32_t flags;
    void *x;
    size_t obj_alloc_size;
    size_t vt_alloc_size;
    ${prefix}Callback **callbacks;
    boil_method_t methods[$num_methods];
} $vt_type;
$vt
$vtable_object

#ifdef ${PREFIX}USE_SHORT_NAMES
  #define $struct_name $prefix$struct_name
  #define $vtable_var $PREFIX$vtable_var
$short_names
#endif /* ${PREFIX}USE_SHORT_NAMES */

END_STUFF
}

sub to_c {
    my $self   = shift;
    my $client = $self->{client};

    return $client->get_autocode if $client->inert;

    my $include_h      = $self->include_h;
    my $class_name_def = $self->name_var_definition;
    my $vtable_def     = $self->vtable_definition;
    my $autocode       = $client->get_autocode;
    my $offsets        = '';
    my $abstract_funcs = '';
    my $callback_funcs = '';
    my $callbacks      = '';

    my $prefix   = $self->get_prefix;
    my $PREFIX   = $self->get_PREFIX;
    my $vt_type  = $PREFIX . $self->vtable_type;
    my $meth_num = 0;
    my @class_callbacks;
    my %novel = map { ( $_->micro_sym => $_ ) } $client->novel_methods;

    for my $method ( $client->get_methods ) {
        my $offset = "(offsetof($vt_type, methods)"
            . " + $meth_num * sizeof(boil_method_t))";
        my $var_name = $method->offset_var_name( $self->{cnick} );
        $offsets .= "size_t $var_name = $offset;\n";

        if ( $method->abstract ) {
            if ( $novel{ $method->micro_sym } ) {
                $callback_funcs .= $method->abstract_method_def . "\n";
            }
        }

        # Define callbacks for methods that can be overridden via the
        # host.
        if ( $method->public or $method->abstract ) {
            my $callback_sym = $method->full_callback_sym;
            if ( $novel{ $method->micro_sym } ) {
                $callback_funcs .= $method->callback_def . "\n";
                my $callback_obj = $method->callback_obj( offset => $offset );
                $callbacks
                    .= "${prefix}Callback $callback_sym = $callback_obj;\n";
            }
            push @class_callbacks, "&$callback_sym";
        }
        $meth_num++;
    }

    my $callbacks_var = $PREFIX . $self->vtable_var . "_CALLBACKS";
    $callbacks .= "${prefix}Callback *$callbacks_var" . "[] = {\n    ";
    $callbacks .= join( ",\n    ", @class_callbacks, "NULL" );
    $callbacks .= "\n};\n";

    return <<END_STUFF;
#include "$include_h"

$offsets
$callback_funcs
$callbacks
$class_name_def
$vtable_def
$autocode

END_STUFF
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Core::Class - Generate core C code for a class.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
