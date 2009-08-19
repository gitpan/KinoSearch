use strict;
use warnings;

package Boilerplater::Binding::Perl::XSub;
use Carp;
use Boilerplater::Class;
use Boilerplater::Function;
use Boilerplater::Method;
use Boilerplater::Variable;
use Boilerplater::ParamList;
use Boilerplater::Util qw( verify_args );

our %new_PARAMS = (
    param_list         => undef,
    aliases            => undef,
    class_name         => undef,
    use_labeled_params => undef,
    retval_type        => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, ref($either) || $either;
    confess("at least one alias required")
        unless scalar @{ $self->{aliases} };
    for (qw( param_list class_name )) {
        confess("$_ is required") unless defined $self->{$_};
    }
    return $self;
}

sub max_alias_num      { $#{ shift->{aliases} } }
sub get_class_name     { shift->{class_name} }
sub use_labeled_params { shift->{use_labeled_params} }

sub perl_name { shift->full_alias(0) }

# Fully-qualified perl sub name.
sub full_alias {
    my ( $self, $alias_num ) = @_;
    my $micro_sym = $self->{aliases}[$alias_num];
    return unless $micro_sym;
    return "$self->{class_name}::$micro_sym";
}

# Name of the C function that implements the XSUB.
sub c_name {
    my $self   = shift;
    my $c_name = "XS_" . $self->perl_name;
    $c_name =~ s/:+/_/g;
    return $c_name;
}

# Names of arguments to feed to bound C function.
sub c_name_list {
    my $self = shift;
    return $self->{param_list}->name_list;
}

my %params_hash_vals_map = (
    NULL  => 'undef',
    true  => 1,
    false => 0,
);

# Create a perl hash where all the keys are the names of labeled params.
sub params_hash_def {
    my $self = shift;
    return unless $self->{use_labeled_params};

    my $params_hash_name = $self->perl_name . "_PARAMS";
    my $arg_vars         = $self->{param_list}->get_variables;
    my $vals             = $self->{param_list}->get_initial_values;
    my @pairs;
    for ( my $i = 1; $i < @$arg_vars; $i++ ) {
        my $var = $arg_vars->[$i];
        my $val = $vals->[$i];
        if ( !defined $val ) {
            $val = 'undef';
        }
        elsif ( exists $params_hash_vals_map{$val} ) {
            $val = $params_hash_vals_map{$val};
        }
        push @pairs, $var->micro_sym . " => $val,";
    }

    if (@pairs) {
        my $list = join( "\n    ", @pairs );
        return qq|\%$params_hash_name = (\n    $list\n);\n|;
    }
    else {
        return qq|\%$params_hash_name = ();\n|;
    }
}

# Generate declarations for vars needed by XSUB binding.
sub var_declarations {
    my $self     = shift;
    my $arg_vars = $self->{param_list}->get_variables;
    my @var_declarations;
    for my $i ( 0 .. $#$arg_vars ) {
        my $arg_var = $arg_vars->[$i];
        push @var_declarations, $arg_var->local_declaration;
        next if $i == 0;    # no ZombieCharBuf for $self.
        next
            unless $arg_var->get_type->get_specifier
                =~ /^kino_(Obj|ByteBuf|CharBuf)$/;
        push @var_declarations,
              'kino_ZombieCharBuf '
            . $arg_var->micro_sym
            . '_zcb = KINO_ZCB_BLANK;';
    }
    if ( defined $self->{retval_type} ) {
        my $return_type = $self->{retval_type}->to_c;
        push @var_declarations, "$return_type retval;";
    }
    if ( $self->{use_labeled_params} ) {
        push @var_declarations,
            map { "SV* " . $_->micro_sym . "_sv = NULL;" }
            @$arg_vars[ 1 .. $#$arg_vars ];
    }
    return join( "\n        ", @var_declarations );
}

# Return C code defining the XSUB.
sub xsub_def { confess "Abstract method" }

1;
