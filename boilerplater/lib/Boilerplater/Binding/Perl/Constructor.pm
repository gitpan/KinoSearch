use strict;
use warnings;

package Boilerplater::Binding::Perl::Constructor;
use base qw( Boilerplater::Binding::Perl::Subroutine );
use Carp;
use Boilerplater::Binding::Perl::TypeMap qw( from_perl );
use Boilerplater::ParamList;

sub new {
    my ( $either, %args ) = @_;
    my $class          = delete $args{class};
    my $alias          = delete $args{alias};
    my $init_func_name = $alias =~ s/^(\w+)\|(\w+)$/$1/ ? $2 : 'init';
    my $class_name     = $class->get_class_name;
    my $func;
    for my $function ( $class->functions ) {
        next unless $function->micro_sym eq $init_func_name;
        $func = $function;
        last;
    }
    confess("Missing or invalid init() function for $class_name")
        unless $func;

    my $self = $either->SUPER::new(
        param_list         => $func->get_param_list,
        retval_type        => $func->get_return_type,
        class_name         => $class_name,
        use_labeled_params => 1,
        alias              => $alias,
        %args
    );
    $self->{init_func} = $func;

    return $self;
}

sub xsub_def {
    my $self       = shift;
    my $c_name     = $self->c_name;
    my $param_list = $self->{param_list};
    my $name_list  = $param_list->name_list;
    my $arg_inits  = $param_list->get_initial_values;
    my $num_args   = $param_list->num_vars;
    my $arg_vars   = $param_list->get_variables;
    my $func_sym   = $self->{init_func}->full_func_sym;

    my $var_declarations = $self->var_declarations;
    my $params_hash_name = $self->perl_name . "_PARAMS";
    my @var_assignments;
    my @refcount_mods;
    my $allot_params
        = qq|XSBind_allot_params( &(ST(0)), 1, items, "$params_hash_name",\n|;

    for ( my $i = 1; $i <= $#$arg_vars; $i++ ) {
        my $var        = $arg_vars->[$i];
        my $val        = $arg_inits->[$i];
        my $name       = $var->micro_sym;
        my $sv_name    = $name . "_sv";
        my $stack_name = $name . "_zcb";
        my $type       = $var->get_type;
        my $len        = length $name;

        # Code for extracting sv from stack, if supplied.
        $allot_params .= qq|            &$sv_name, "$name", $len,\n|;

        # Code for determining and validating value.
        my $statement = from_perl( $type, $name, $sv_name, $stack_name );
        if ( defined $val ) {
            my $assignment = qq|if ($sv_name && XSBind_sv_defined($sv_name)) {
            $statement
        }
        else {
            $name = $val;
        }|;
            push @var_assignments, $assignment;
        }
        else {
            my $assignment
                = qq#if ( !$sv_name || !XSBind_sv_defined($sv_name) ) {
           THROW(KINO_ERR, "Missing required param '$name'");
        }
        $statement#;
            push @var_assignments, $assignment;
        }

        if ( $type->is_object and $type->decremented ) {
            push @refcount_mods, "if ($name) { KINO_INCREF($name); }";
        }
    }
    $allot_params .= "            NULL);\n";

    # Last, so that earlier exceptions while fetching params don't trigger bad
    # DESTROY.
    my $self_var  = $arg_vars->[0];
    my $self_type = $self_var->get_type->to_c;
    push @var_assignments,
        qq|self = ($self_type)XSBind_new_blank_obj( ST(0) );|;

    my $var_assignments
        = join( "\n        ", $allot_params, @var_assignments );
    my $refcount_mods = join( "\n        ", @refcount_mods );

    return <<END_STUFF;
XS($c_name); /* -Wmissing-prototypes */
XS($c_name)
{
    dXSARGS;
    CHY_UNUSED_VAR(cv);
    CHY_UNUSED_VAR(ax);
    if (items < 1)
        THROW(KINO_ERR, "Usage: %s(class_name, ...)",  GvNAME(CvGV(cv)));
    SP -= items;

    {
        $var_declarations
        $var_assignments
        $refcount_mods
        retval = $func_sym($name_list);
        ST(0) = Kino_Obj_To_Host(retval);
        KINO_DECREF(retval);
        sv_2mortal( ST(0) );
        XSRETURN(1);
    }

    PUTBACK;
}

END_STUFF
}

1;
