use strict;
use warnings;

package Boilerplater::Method;
use Carp;
use base qw( Boilerplater::Function );

sub new {
    my ( $class, %args ) = @_;
    my $abstract   = delete $args{abstract};
    my $final      = delete $args{final};
    my $macro_name = delete $args{macro_name};
    confess "macro_name is required" unless $macro_name;
    $args{micro_sym} ||= lc($macro_name);
    my $self = $class->SUPER::new(%args);
    $self->{macro_name} = $macro_name;
    $self->{abstract}   = $abstract;
    $self->{final}      = $final;
    my $param_list = $self->get_param_list;
    my $args       = $param_list->get_variables;

    # Assume that this method is novel until we discover when applying
    # inheritance that it was overridden.
    $self->{novel} = 1;

    # Count the number of arguments and produce a symbolic list.
    $self->{arg_names} = join ', ', map { $_->micro_sym } @$args;

    # Verify that the first element in the arg list is a self.
    confess "not enough args" unless @$args;
    my $specifier = $args->[0]->get_type->get_specifier;
    my ($struct_name) = $self->{class_name} =~ /(\w+)$/;
    confess
        "First arg type doesn't match class: $self->{class_name} $specifier"
        unless $specifier eq $self->get_prefix . $struct_name;

    # Transform method_name to Method_Name, validate.
    if ( !defined $self->{macro_name} ) {
        $self->{macro_name} = $self->{micro_sym};
        $self->{macro_name} =~ s/((?:^|_).)/\U$1/g;
    }
    confess("Invalid macro_name: '$self->{macro_name}'")
        unless $self->{macro_name}
            =~ /^[A-Z][A-Za-z0-9]*(?:_[A-Z0-9][A-Za-z0-9]*)*$/;

    if ( !defined $self->{typedef} ) {
        $self->{typedef}     = $self->_gen_typedef;
        $self->{typedef_dec} = $self->_gen_typedef_dec;
    }

    return $self;
}

sub abstract       { shift->{abstract} }
sub novel          { shift->{novel} }
sub final          { shift->{final} }
sub get_macro_name { shift->{macro_name} }

sub full_macro_name {
    my ( $self, $invoker ) = @_;
    return $self->get_Prefix . $invoker . "_$self->{macro_name}";
}

sub self_type { shift->get_param_list->get_variables->[0]->get_type }

=begin comment

Let a Boilerplater::Method object know that it is overriding a method which
was defined in a parent class.

All methods start out as plain old Method objects, because we don't know about
inheritance until we build the hierarchy after all files have been parsed.
override() is a way of going back and relabeling a method as overridden when
new information has become available: in this case, that a parent class has
defined a method with the same name.

=end comment
=cut 

sub override {
    my ( $self, $orig ) = @_;

    # Check that the override attempt is legal.
    confess(  "Attempt to override final method '$orig->{micro_sym}' from "
            . "$orig->{class_cnick} by $self->{class_cnick}" )
        if $orig->final;
    if ( !$self->_compatible($orig) ) {
        my $func_name = $self->full_func_sym;
        my $orig_func = $orig->full_func_sym;
        confess("Non-matching signatures for $func_name and $orig_func");
    }

    # Mark the Method as no longer novel.
    $self->{novel} = 0;
}

# Return true if the method signature is compatible.
sub _compatible {
    my ( $self, $other ) = @_;
    return 0 if !$self->public && $other->public;
    my $arg_vars       = $self->{param_list}->get_variables;
    my $other_vars     = $other->{param_list}->get_variables;
    my $initial_values = $self->{param_list}->get_initial_values;
    my $other_values   = $other->{param_list}->get_initial_values;
    return 0 unless @$arg_vars == @$other_vars;

    for ( my $i = 1; $i <= $#$arg_vars; $i++ ) {
        return 0 unless $other_vars->[$i]->equals( $arg_vars->[$i] );
        next
            unless defined( $other_values->[$i] )
                && defined( $initial_values->[$i] );
        return 0 unless $other_values->[$i] eq $initial_values->[$i];
    }
    return 1;
}

=begin comment

As with override, above, this is for going back and changing the nature of a
Method object after new information has become available -- typically, when we
discover that the method has been inherited by a "final" class.

However, we don't rebless the object as with override().  Inherited Method
objects are shared between parent and child classes; if a shared Method object
were to become final, it would interfere with its own inheritance.  So, we
make a copy, slightly modified to make it "final".

=end comment
=cut

sub finalize {
    my $self = shift;
    return bless {
        %$self,
        # These are needed in case this method is overriding another.
        typedef_dec => $self->typedef_dec,
        typedef     => $self->typedef,
        final       => 1,
        },
        ref($self);
}

# Create the name of the function pointer typedef for the method's
# implementing function.
sub typedef { shift->{typedef} }

sub _gen_typedef {
    my $self = shift;
    return "$self->{class_cnick}_$self->{micro_sym}_t";
}

# Create a function pointer typedef.
sub typedef_dec { shift->{typedef_dec} }

sub _gen_typedef_dec {
    my $self        = shift;
    my $prefix      = $self->get_prefix;
    my $params      = $self->{param_list}->to_c;
    my $return_type = $self->{return_type}->to_c;
    return <<END_STUFF;
typedef $return_type
(*$prefix$self->{class_cnick}_$self->{micro_sym}_t)($params);
END_STUFF
}

# The typedef's short name.
sub short_typedef {
    my $self       = shift;
    my $prefix     = $self->get_prefix;
    my $short_name = "$self->{class_cnick}_$self->{micro_sym}_t";
    return "  #define $short_name $prefix$short_name\n";
}

# The method macro's short name.
sub short_method_macro {
    my ( $self, $invoker ) = @_;
    my $Prefix     = $self->get_Prefix;
    my $short_name = $invoker . "_$self->{macro_name}";
    return "  #define $short_name $Prefix$short_name\n";
}

# The name of the variable which stores the method's vtable offset.
sub offset_var_name {
    my ( $self, $invoker ) = @_;
    return $self->get_Prefix . "$invoker\_$self->{macro_name}_OFFSET";
}

sub abstract_method_def {
    my $self            = shift;
    my $params          = $self->{param_list}->to_c;
    my $full_func_sym   = $self->full_func_sym;
    my $vtable          = uc( $self->self_type->get_specifier );
    my $return_type     = $self->{return_type};
    my $return_type_str = $return_type->to_c;

    # Build list of unused params and create an unreachable return statement
    # if necessary, in order to thwart compiler warnings.
    my $param_vars = $self->{param_list}->get_variables;
    my $unused     = "";
    for ( my $i = 1; $i < @$param_vars; $i++ ) {
        my $var_name = $param_vars->[$i]->micro_sym;
        $unused .= "\n    CHY_UNUSED_VAR($var_name);";
    }
    my $ret_statement = '';
    if ( !$return_type->void ) {
        $ret_statement = "\n    CHY_UNREACHABLE_RETURN($return_type_str);";
    }

    return <<END_ABSTRACT_DEF;
$return_type_str
$full_func_sym($params)
{
    kino_CharBuf *klass = self ? Kino_Obj_Get_Class_Name(self) : $vtable->name;$unused
    KINO_THROW(KINO_ERR, "Abstract method '$self->{macro_name}' not defined by %o", klass);$ret_statement
}
END_ABSTRACT_DEF
}

sub callback_def {
    my $self        = shift;
    my $return_type = $self->get_return_type;
    return
          $return_type->void      ? _void_callback_def($self)
        : $return_type->is_object ? _obj_callback_def($self)
        :                           _primitive_callback_def($self);
}

sub _callback_params {
    my $self       = shift;
    my $micro_sym  = $self->micro_sym;
    my $param_list = $self->{param_list};
    my $num_params = $param_list->num_vars - 1;
    my $arg_vars   = $param_list->get_variables;
    my @params;
    for my $var ( @$arg_vars[ 1 .. $#$arg_vars ] ) {
        my $name = $var->micro_sym;
        my $type = $var->get_type;
        my $param
            = $type->is_string_type ? qq|KINO_ARG_STR("$name", $name)|
            : $type->is_object      ? qq|KINO_ARG_OBJ("$name", $name)|
            : $type->is_integer     ? qq|KINO_ARG_I32("$name", $name)|
            :                         qq|KINO_ARG_F("$name", $name)|;
        push @params, $param;
    }
    return join( ', ', 'self', qq|"$micro_sym"|, $num_params, @params );
}

sub _void_callback_def {
    my $self            = shift;
    my $override_sym    = $self->full_override_sym;
    my $callback_params = _callback_params($self);
    my $params          = $self->{param_list}->to_c;
    return <<END_CALLBACK_DEF;
void
$override_sym($params)
{
    kino_Host_callback($callback_params);
}
END_CALLBACK_DEF
}

sub _primitive_callback_def {
    my $self            = shift;
    my $override_sym    = $self->full_override_sym;
    my $callback_params = _callback_params($self);
    my $params          = $self->{param_list}->to_c;
    my $return_type     = $self->{return_type}->to_c;
    my $nat_func
        = $self->{return_type}->is_floating ? 'kino_Host_callback_f'
        : $self->{return_type}->is_integer  ? 'kino_Host_callback_i'
        : $return_type eq 'void*' ? 'kino_Host_callback_nat'
        :   confess("unrecognized type: $return_type");
    return <<END_CALLBACK_DEF;
$return_type
$override_sym($params)
{
    return ($return_type)$nat_func($callback_params);
}
END_CALLBACK_DEF
}

sub _obj_callback_def {
    my $self            = shift;
    my $override_sym    = $self->full_override_sym;
    my $callback_params = _callback_params($self);
    my $params          = $self->{param_list}->to_c;
    my $return_type     = $self->{return_type}->to_c;
    my $cb_func_name
        = $self->{return_type}->is_string_type
        ? 'kino_Host_callback_str'
        : 'kino_Host_callback_obj';
    if ( $self->{return_type}->incremented ) {
        return <<END_CALLBACK_DEF;
$return_type
$override_sym($params)
{
    return ($return_type)$cb_func_name($callback_params);
}
END_CALLBACK_DEF
    }
    else {
        return <<END_CALLBACK_DEF;
$return_type
$override_sym($params)
{
    $return_type retval = ($return_type)$cb_func_name($callback_params);
    KINO_DECREF(retval);
    return retval;
}
END_CALLBACK_DEF
    }
}

sub full_callback_sym { shift->full_func_sym . "_CALLBACK" }
sub full_override_sym { shift->full_func_sym . "_OVERRIDE" }

sub callback_dec {
    my $self         = shift;
    my $callback_sym = $self->full_callback_sym;
    return qq|extern kino_Callback $callback_sym;|;
}

sub callback_obj {
    my ( $self, %args ) = @_;
    my $func_sym = $self->full_override_sym;
    return qq|KINO_CALLBACK_DEC("$self->{macro_name}", |
        . qq|$func_sym, $args{offset})|;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Method - Metadata describing an instance method.

=head1 DESCRIPTION

Boilerplater::Method is a specialized subclass of Boilerplater::Function, with
the first argument required to be an Obj.

When compiling Boilerplater code to C, Method objects generate all the code
that Function objects do, but also create symbols for indirect invocation via
VTable.

=head1 METHODS

=head2 new

    my $type = Boilerplater::Method->new(
        class_name   => 'MyProject::FooFactory',    # required
        param_list   => $param_list,                # required
        micro_sym    => 'count',                    # required
        macro_name   => 'Count',                    # required
        class_cnick  => 'FooFact ',                 # default: special 
        docu_comment => $docu_comment,              # default: undef
        abstract     => undef,                      # default: undef
        exposure     => undef,                      # default: 'parcel' 
    );

=over

=item *

B<param_list> - A Boilerplater::ParamList.  The first element must be an
object of the class identified by C<class_name>.

=item *

B<micro_sym> - The lower case name of the function which implements the
method.

=item *

B<macro_name> - The mixed case name which will be used when invoking the
method.

=item *

B<abstract> - Indicate whether the method is abstract.  A function body must
still be defined.

=item *

B<exposure> - The scope at which the method is exposed.  Must be one of
'public', 'parcel' or 'private'.

=item *

B<class_name>, B<class_cnick>, B<docu_comment>, see L<Boilerplater::Function>.

=back

=head1 COPYRIGHT

Copyright 2006-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
