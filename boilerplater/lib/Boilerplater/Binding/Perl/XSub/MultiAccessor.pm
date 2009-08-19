use strict;
use warnings;

package Boilerplater::Binding::Perl::XSub::MultiAccessor;
use base qw( Boilerplater::Binding::Perl::XSub );
use Carp;
use Boilerplater::Type::Object;
use Boilerplater::Variable;
use Boilerplater::ParamList;
use Boilerplater::Binding::Perl::TypeMap qw( from_perl to_perl );

# Constructor from a Boilerplater::Class, to create an XSUB which supports
# several set/get accessors.
sub new {
    my ( $either, %args ) = @_;
    my $class      = delete $args{class};
    my $getters    = delete( $args{getters} ) || [];
    my $setters    = delete( $args{setters} ) || [];
    my $class_name = $class->get_class_name;

    my $self_type = Boilerplater::Type::Object->new(
        parcel      => $class->get_parcel,
        specifier   => $class->get_prefix . $class->get_struct_name,
        indirection => 1,
    );
    my $self_var = Boilerplater::Variable->new(
        type      => $self_type,
        micro_sym => 'self',
    );
    my $param_list = Boilerplater::ParamList->new(
        variables => [$self_var],
        variadic  => 1,
    );

    my $alias_num = 0;
    my @aliases   = ("_set_or_get");
    my @cases;
    my %setters = map { ( $_ => 1 ) } @$setters;
    my %getters = map { ( $_ => 1 ) } @$getters;
    for my $var ( $class->novel_member_vars ) {
        my $var_type    = $var->get_type;
        my $var_name    = $var->micro_sym;
        my $stack_name  = $var_name . "_zcb";
        my $make_setter = delete $setters{$var_name};
        my $make_getter = delete $getters{$var_name};
        next unless $make_setter || $make_getter;

        $alias_num++;
        if ($make_setter) {
            $aliases[$alias_num] = "set_$var_name";
            my $set_case = from_perl( $var_type, "self->$var_name", "ST(1)",
                $stack_name );
            if ( $var->get_type->is_object ) {
                $set_case = "{\n             KINO_DECREF(self->$var_name);"
                    . "\n            $set_case\n        }\n";
            }
            $set_case = "case $alias_num: $set_case";
            $set_case .= "\n           break;";
            push @cases, $set_case;
        }

        if ($make_getter) {
            $alias_num++;
            $aliases[$alias_num] = "get_$var_name";
            my $get_case = "case $alias_num: ";
            $get_case .= to_perl( $var_type, "retval", "self->$var_name" );
            $get_case .= "\n           break;";
            push @cases, $get_case;
        }
    }
    my $cases = join( "\n        ", @cases );
    my @leftover = ( keys %setters, keys %getters );
    confess("Can't find members in '$class_name': '@leftover'") if @leftover;

    my $body = qq|{
        START_SET_OR_GET_SWITCH
        $cases
        END_SET_OR_GET_SWITCH
    }|;

    my $self = $either->SUPER::new(
        param_list         => $param_list,
        aliases            => \@aliases,
        class_name         => $class_name,
        use_labeled_params => 0,
    );
    $self->{body} = $body;

    return $self;
}

# Return C code defining the XSUB.
sub xsub_def {
    my $self       = shift;
    my $c_name     = $self->c_name;
    my $param_list = $self->{param_list};
    my $arg_vars   = $param_list->get_variables;

    my $self_type     = $arg_vars->[0]->get_type;
    my $vtable        = uc( $self_type->get_specifier );
    my $self_type_str = $self_type->to_c;
    my $self_assignment
        = qq|self = ($self_type_str)XSBind_sv_to_kobj(ST(0), $vtable);|;

    return <<END_STUFF;
XS($c_name); /* -Wmissing-prototypes */
XS($c_name)
{
    dXSARGS;
    dXSI32;
    $self_type_str self = NULL;
    CHY_UNUSED_VAR(cv);
    CHY_UNUSED_VAR(ax);
    SP -= items;

    if (items >= 1) { /* full args check in upcoming macro */
        $self_assignment;
    }

    $self->{body}

    PUTBACK;
}
END_STUFF
}

1;
