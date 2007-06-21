use strict;
use warnings;

package Boilerplater::Class;
use Carp;
use Config;
use Boilerplater qw( $prefix $Prefix $PREFIX );
use Boilerplater::Util qw( strip_c_comments current slurp_file );
use Boilerplater::Function;
use Boilerplater::MemberVar;
use Boilerplater::Method;
use Boilerplater::Method::Final;
use Boilerplater::Method::Overridden;

sub new {
    my $class_class = shift;
    my $self        = bless {
        h_path            => undef,
        r_path            => undef,
        o_path            => undef,
        content           => undef,
        class_name        => undef,
        class_nick        => undef,
        struct_name       => undef,
        parent_class_name => undef,
        methods           => [],
        overridden        => {},
        functions         => [],
        member_vars       => [],
        children          => [],
        parent            => undef,
        @_
    }, $class_class;

    # derive some filepaths
    my ($path_minus_ext) = $self->{h_path} =~ /(.*)\.h/;
    $self->{o_path} = "$path_minus_ext$Config{_o}";

    # parse the source and extract class elements
    $self->{content} = strip_c_comments( $self->{content} );
    $self->_extract_class_names;
    $self->_extract_member_vars;
    $self->_extract_methods_and_functions;

    # verify that all text within class definition was consumed
    $self->{content} =~ s/${PREFIX}END_CLASS\s*// or confess "no match";
    $self->_verify_complete_parse( $self->{content} );

    return $self;
}

# Accessors.
sub get_h_path            { shift->{h_path} }
sub get_o_path            { shift->{o_path} }
sub get_r_path            { shift->{r_path} }
sub get_class_name        { shift->{class_name} }
sub get_parent_class_name { shift->{parent_class_name} }
sub get_methods           { @{ shift->{methods} } }
sub get_member_vars       { @{ shift->{member_vars} } }
sub get_children          { @{ shift->{children} } }
sub get_parent            { shift->{parent} }

# Return a string used identify include guard, unique per file.
sub guard_name {
    my $self   = shift;
    my $r_path = $self->get_r_path;
    my ($guard_name) = $r_path =~ m/(\w+)\.r$/;
    $guard_name = uc("R_$PREFIX$guard_name");
    return $guard_name;
}

# Return a string opening the include guard.
sub guard_start {
    my $self       = shift;
    my $guard_name = $self->guard_name;
    return "#ifndef $guard_name\n#define $guard_name 1\n";
}

# Return a string closing the include guard.  Other classes count on being
# able to match this string.
sub guard_close {
    my $self       = shift;
    my $guard_name = $self->guard_name;
    return "#endif /\* $guard_name \*/\n";
}

# Inheriting is allowed.
sub is_final {0}

# Add a child to this class.
sub add_child {
    my ( $self, $child ) = @_;
    push @{ $self->{children} }, $child;
}

# Bequeath all inherited methods and members to children.
sub bequeath {
    my $self = shift;

    for my $child ( @{ $self->{children} } ) {
        # This is a circular reference and thus a memory leak, but we don't
        # care, because we have to have everything in memory at once anyway.
        $child->{parent} = $self;

        # pass down member vars
        unshift @{ $child->{member_vars} }, @{ $self->{member_vars} };

        # pass down methods, with some being overridden
        my @common_methods;    # methods which child inherits or overrides
        for my $method ( @{ $self->{methods} } ) {
            if ( exists $child->{meth_by_name}{ $method->get_micro_name } ) {
                my $child_method
                    = $child->{meth_by_name}{ $method->get_micro_name };
                $child_method->override($method);
                push @common_methods, $child_method;
            }
            else {
                push @common_methods, $method;
            }
        }

        # create array of methods, preserving exact order so vtables match up
        my @new_method_set;
        my %seen;
        for my $meth ( @common_methods, @{ $child->{methods} } ) {
            next if $seen{ $meth->get_micro_name };
            $seen{ $meth->get_micro_name } = 1;
            $meth = $meth->finalize if $child->is_final;
            push @new_method_set, $meth;
        }
        $child->{methods} = \@new_method_set;

        # pass it all down to the next generation
        $child->bequeath;
    }
}

# Parse BOIL_CLASS section.
sub _extract_class_names {
    my $self    = shift;
    my $quot_re = qr/\s*"(.*?)"\s*/;
    $self->{content}
        =~ s/^$PREFIX(?:FINAL_)?CLASS\($quot_re,$quot_re,$quot_re\)\s*;//m
        or confess "Couldn't match BOIL_CLASS definition";
    @{$self}{qw( class_name class_nick parent_class_name )} = ( $1, $2, $3 );
    ( $self->{struct_name} ) = $self->{class_name} =~ /(\w+)$/;
}

# Make sure that the parser consumed all non-whitespace characters.
sub _verify_complete_parse {
    my ( $self, $leftover ) = @_;
    if ( $leftover =~ /\S/ ) {
        confess "non-parseable content in $self->{h_path}:\n$leftover";
    }
}

# Parse function declarations and BOIL_METHOD directives.
sub _extract_methods_and_functions {
    my $self = shift;
    my ( %method_names, %final_method_names );

    # extract BOIL_METHOD names
    while ( $self->{content}
        =~ s/^$PREFIX(FINAL_)?METHOD\s*\(\s*"(\w+)"\s*\);//ms )
    {
        my $final = $self->is_final || defined $1;
        my $full_method_name = $2;
        if ($final) {
            $final_method_names{ lc($full_method_name) } = $full_method_name;
        }
        else {
            $method_names{ lc($full_method_name) } = $full_method_name;
        }
    }

    # extract function declarations
    my $func_re = _func_re();
    while ( $self->{content} =~ s/^$func_re//ms ) {
        my $return_type  = $1;
        my $class_nick   = $2;
        my $micro_name   = $3;
        my $arg_list     = $4;
        my $lc_func_name = lc( $prefix . $class_nick . '_' . $micro_name );
        my $final        = 0;
        my $macro_name;

        # verify class nick
        confess( "Class nick '$class_nick' for '$micro_name' doesnt' match "
                . $self->{class_nick} )
            unless $class_nick eq $self->{class_nick};

        # match to a method if possible, fall back to a function
        my $beginning = $Prefix . $class_nick . '_';
        if ( exists $method_names{$lc_func_name} ) {
            $macro_name = delete $method_names{$lc_func_name};
            $macro_name =~ s/^$beginning//
                or confess("Illegal method name: $macro_name");
        }
        elsif ( exists $final_method_names{$lc_func_name} ) {
            $macro_name = delete $final_method_names{$lc_func_name};
            $macro_name =~ s/^$beginning//
                or confess("Illegal method name: $macro_name");
            $final = 1;
        }

        if ( defined $macro_name ) {
            my $meth_class
                = $final
                ? 'Boilerplater::Method::Final'
                : 'Boilerplater::Method';
            my $method = $meth_class->new(
                return_type => $return_type,
                micro_name  => $micro_name,
                macro_name  => $macro_name,
                class_name  => $self->{class_name},
                class_nick  => $self->{class_nick},
                struct_name => $self->{struct_name},
                arg_list    => $arg_list,
            );
            $self->{meth_by_name}{$micro_name} = $method;
            push @{ $self->{methods} }, $method;
        }
        else {
            my $function = Function->new(
                return_type => $return_type,
                micro_name  => $micro_name,
                class_name  => $self->{class_name},
                class_nick  => $self->{class_nick},
                struct_name => $self->{struct_name},
                arg_list    => $arg_list,
            );
            push @{ $self->{functions} }, $function;
        }
    }
}

# Return a regex for matching a function (or "method") declaration.
sub _func_re {
    return qr{
            \s*
            ( [^(;]+  ? )       # return type $1
            \s*
            $prefix([a-zA-Z]+)_ # prefix and class_nick $2
            ([a-z_][a-z_0-9]+)  # micro name $3
            \s*\(               # opening paren
            ( [^;]*? )          # arg list $4
            \);                 # closing paren and terminating semicolon
        }xsm;
}

# Parse struct definition.
sub _extract_member_vars {
    my $self        = shift;
    my $member_vars = $self->{member_vars};

    $self->{content} =~ s/(^\s*struct\s+$prefix\w+\s+{.*?}\s*;)//ms
        or confess("Couldn't extract struct definition in $self->{h_path}");
    my $obj_section = $1;

    # remove the struct definition wrapper
    $obj_section =~ s/^\s*struct\s+$prefix\w+\s+{\s+//
        or confess("Unrecognized text in object section: $obj_section");
    $obj_section =~ s/};\s*$//
        or confess("Unrecognized text in object section: $obj_section");

    # blow past the VTABLE
    $obj_section =~ s/^\s*$PREFIX\w+\s+\*_;//
        or confess("Invalid object definition: $obj_section");

    # ignore the macro indicating inherited member vars, if present
    $obj_section =~ s/^\s*$PREFIX\w+_MEMBER_VARS;\s*//;

    # create one MemberVar object per var
    while ( $obj_section =~ s/\s*([^;]+?)(\b[\w\[\]]+);// ) {
        my ( $type, $name ) = ( $1, $2 );
        $type =~ s/\s+/ /g;    # collapse whitespace on the type
        push @$member_vars, MemberVar->new( type => $type, name => $name );
    }
    $self->_verify_complete_parse($obj_section);
}

# Print representation to file if it's not up to date with either its own
# .h file or any ancestor.
sub write_if_modified {
    my ( $self, $modified ) = @_;

    # propagate modification status
    if ( !current( $self->{h_path}, $self->{r_path} ) ) {
        $modified = 1;
    }

    # print boilerplate if needed
    if ($modified) {
        my $r_path = $self->{r_path};
        my $bp_tag = $PREFIX . uc( $self->{struct_name} ) . "_BOILERPLATE";
        my $guard_name = $self->guard_name;
        print "writing $self->{struct_name} to $r_path\n";

        # either replace or insert just before include guard
        my $content = slurp_file($r_path);
        my $bp
            = "#define $bp_tag\n"
            . $self->_gen_boilerplate
            . "\n#undef $bp_tag\n\n\n";
        if ( $content =~ /$bp_tag/ ) {
            $content =~ s/#define $bp_tag.*?#undef $bp_tag\n\n\n/$bp/s;
        }
        else {
            my $guard_close = $self->guard_close;
            $content =~ s{(?=\Q$guard_close\E)}{$bp} or die "no match";
        }

        open( my $fh, '>', $r_path ) or confess "Can't open '$r_path': $!";
        print $fh $content;
    }

    return $modified;
}

# Generate boilerplate code.
sub _gen_boilerplate {
    my $self = shift;
    my ( $class_nick, $methods, $struct_name )
        = @{$self}{qw( class_nick methods struct_name )};
    my $uc_class_nick = uc($class_nick);
    my $uc_struct     = uc($struct_name);
    my $vtable_name   = "$PREFIX$uc_struct";
    my $vtable_type   = $vtable_name . '_VTABLE';

    # collect non-inherited methods
    my @native_methods
        = grep { $_->get_class_nick eq $self->{class_nick} } @$methods;

    # declare typedefs for native methods, to ease casting
    my $method_typedefs = '';
    for my $method (@native_methods) {
        $method_typedefs .= $method->typedef_dec . "\n";
    }

    # define method macros
    my $method_macros = '';
    for my $method (@$methods) {
        $method_macros .= $method->macro_def($class_nick) . "\n";
    }

    # define the methods that go in the virtual table declaration
    my $vtable_method_list = '';
    for my $method (@$methods) {
        $vtable_method_list
            .= "    $prefix"
            . $method->typedef . " "
            . $method->get_micro_name . ";\n";
    }

    # declare the virtual table object
    my $vtable_object = "extern $vtable_type $vtable_name;";

    # define short names
    my $short_names = '';
    for my $function ( @{ $self->{functions} } ) {
        $short_names .= $function->short_func;
    }
    for my $method (@native_methods) {
        $short_names .= $method->short_typedef
            unless $method->isa("Boilerplater::Method::Overridden");
        $short_names .= $method->short_func;
    }
    for my $method (@$methods) {
        $short_names .= $method->short_method_macro($class_nick);
    }

    # define member vars macro
    my $member_vars_def
        = "#define $PREFIX$uc_struct" . "_MEMBER_VARS \\\n    ";
    my @declarations
        = map { $_->get_type . " " . $_->get_name } @{ $self->{member_vars} };
    $member_vars_def .= join( "; \\\n    ", @declarations );

    # define the vtable
    my $vtable_definition = $self->_vtable_definition;

    # make the spacing in the file a little more elegant
    s/\s+$//
        for (
        $method_typedefs, $method_macros,   $vtable_method_list,
        $short_names,     $member_vars_def, $vtable_definition
        );

    # put the whole thing together
    return <<END_STUFF;

$method_typedefs

$method_macros

struct $PREFIX${uc_struct}_VTABLE {
    ${PREFIX}OBJ_VTABLE *_;
    chy_u32_t refcount;
    ${PREFIX}OBJ_VTABLE *parent;
    const char *class_name;
$vtable_method_list
};

$vtable_object

#ifdef ${PREFIX}USE_SHORT_NAMES
  #define $struct_name $prefix$struct_name
  #define $uc_struct $PREFIX$uc_struct
$short_names
#endif /* ${PREFIX}USE_SHORT_NAMES */

$member_vars_def

$vtable_definition
END_STUFF
}

# Define the vtable.
sub _vtable_definition {
    my $self      = shift;
    my $uc_struct = uc( $self->{struct_name} );

    # create a pointer to the parent class's vtable
    my $parent_ref = "NULL";    # Obj only
    if ( defined $self->{parent} ) {
        $parent_ref = "(${PREFIX}OBJ_VTABLE*)"
            . uc("&$PREFIX$self->{parent}{struct_name}");
    }

    # spec functions which implment the methods, casting to quiet compiler
    my @implementing_funcs
        = map { "($prefix" . $_->typedef . ')' . $_->get_full_func_name }
        @{ $self->{methods} };

    # join the vtable's vtable, the vtable's refcount, the parent class's
    # vtable, the class name, and the funcs
    my $vtable = join( ",\n    ",
        "(${PREFIX}OBJ_VTABLE*)&${PREFIX}VIRTUALTABLE",
        '1', $parent_ref, qq|"$self->{class_name}"|, @implementing_funcs );

    return <<END_VTABLE
#ifdef ${PREFIX}WANT_${uc_struct}_VTABLE
${PREFIX}${uc_struct}_VTABLE $PREFIX$uc_struct = {
    $vtable
};
#endif /* ${PREFIX}WANT_${uc_struct}_VTABLE */
END_VTABLE
}

1;
