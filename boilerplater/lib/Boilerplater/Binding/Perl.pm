use strict;
use warnings;

package Boilerplater::Binding::Perl;

use Boilerplater::Session;
use Carp;
use File::Spec::Functions qw( catfile );
use Fcntl;

use Boilerplater::Class;
use Boilerplater::Class::Final;
use Boilerplater::Function;
use Boilerplater::Method;
use Boilerplater::Variable;
use Boilerplater::Util qw( verify_args );
use Boilerplater::Binding::Perl::XSub::Method;
use Boilerplater::Binding::Perl::XSub::MultiAccessor;
use Boilerplater::Binding::Perl::XSub::Constructor;

our %new_PARAMS = (
    session     => undef,
    xs_path     => undef,
    pm_path     => undef,
    xs_code     => undef,
    boot_class  => undef,
    boot_h_file => undef,
    boot_c_file => undef,
    boot_func   => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless {
        %new_PARAMS,
        bind_methods    => {},
        bind_positional => {},
        make_getters    => {},
        make_setters    => {},
        make_pod        => {},
        registered      => {},
        @_,
        },
        ref($either) || $either;
    for ( keys %new_PARAMS ) {
        confess("$_ is mandatory") unless defined $self->{$_};
    }
    return $self;
}

our %add_class_PARAMS = (
    class_name        => undef,
    bind_methods      => undef,
    bind_labeled      => undef,
    bind_positional   => undef,
    make_getters      => undef,
    make_setters      => undef,
    make_constructors => undef,
    make_pod          => undef,
);

# Indicate that bindings are to be auto-generated for the supplied class name.
sub add_class {
    my $self = shift;
    verify_args( \%add_class_PARAMS, @_ ) or confess $@;
    my %args       = @_;
    my $class_name = delete $args{class_name};
    confess("class_name is mandatory") unless $class_name;
    confess("$class_name is already registered")
        if $self->{registered}{$class_name};
    $self->{registered}{$class_name}        = 1;
    $self->{bind_methods}{$class_name}      = $args{bind_methods};
    $self->{bind_labeled}{$class_name}      = $args{bind_labeled};
    $self->{bind_positional}{$class_name}   = $args{bind_positional};
    $self->{make_getters}{$class_name}      = $args{make_getters};
    $self->{make_setters}{$class_name}      = $args{make_setters};
    $self->{make_constructors}{$class_name} = $args{make_constructors};
    $self->{make_pod}{$class_name}          = $args{make_pod};
}

sub write_bindings {
    my $self    = shift;
    my @ordered = $self->{session}->ordered_classes;
    my @xsubs;
    my $xs = "";

    # Pound-includes for generated headers.
    for my $class (@ordered) {
        my $include_h = $class->include_h;
        $xs .= qq|#include "$include_h"\n|;
    }
    $xs .= "\n";

    # Constructors.
    my $make_constructors = $self->{make_constructors};
    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        my $ctor_names = delete $make_constructors->{$class_name};
        next unless $ctor_names;
        for my $ctor_name (@$ctor_names) {
            my $xsub = Boilerplater::Binding::Perl::XSub::Constructor->new(
                class => $class,
                alias => $ctor_name,
            );
            $xs .= $xsub->xsub_def . "\n";
            push @xsubs, $xsub;
        }
    }
    my @leftover_ctor = keys %$make_constructors;
    if (@leftover_ctor) {
        confess(  "Constructor binding spec'd for non-existant classes: "
                . "'@leftover_ctor'" );
    }

    # Accessors.
    my $make_setters = $self->{make_setters};
    my $make_getters = $self->{make_getters};
    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        my $setters    = delete $make_setters->{$class_name};
        my $getters    = delete $make_getters->{$class_name};
        next unless $setters || $getters;
        my $multi_accessor
            = Boilerplater::Binding::Perl::XSub::MultiAccessor->new(
            class   => $class,
            getters => $getters,
            setters => $setters,
            );
        $xs .= $multi_accessor->xsub_def . "\n";
        push @xsubs, $multi_accessor;
    }
    my @leftover = ( keys %$make_setters, keys %$make_getters );
    confess("Unused setters/getters: '@leftover'") if @leftover;

    # Methods.
    my $bind_methods    = $self->{bind_methods};
    my $bind_positional = $self->{bind_positional};
    my $bind_labeled    = $self->{bind_labeled};
    for my $class (@ordered) {
        my $class_name = $class->get_class_name;

        # Assemble a list of methods to be bound for this class.
        my %meth_to_bind;
        if ( my $meth_list = delete $bind_methods->{$class_name} ) {
            for my $meth_namespec (@$meth_list) {
                my ( $alias, $name )
                    = $meth_namespec =~ /^(.*?)\|(.*)$/
                    ? ( $1, $2 )
                    : ( lc($meth_namespec), $meth_namespec );
                $meth_to_bind{$name} = { aliases => [$alias] };
            }
        }
        if ( my $pos_meth_list = delete $bind_positional->{$class_name} ) {
            for my $meth_namespec (@$pos_meth_list) {
                my ( $alias, $name )
                    = $meth_namespec =~ /^(.*?)\|(.*)$/
                    ? ( $1, $2 )
                    : ( lc($meth_namespec), $meth_namespec );
                $meth_to_bind{$name} = {
                    aliases            => [$alias],
                    use_labeled_params => 0
                };
            }
        }
        if ( my $label_meth_list = delete $bind_labeled->{$class_name} ) {
            for my $meth_namespec (@$label_meth_list) {
                my ( $alias, $name )
                    = $meth_namespec =~ /^(.*?)\|(.*)$/
                    ? ( $1, $2 )
                    : ( lc($meth_namespec), $meth_namespec );
                $meth_to_bind{$name} = {
                    aliases            => [$alias],
                    use_labeled_params => 1
                };
            }
        }
        next unless scalar keys %meth_to_bind;

        for my $method ( $class->novel_methods ) {
            my $meth_name  = $method->get_macro_name;
            my $extra_args = delete $meth_to_bind{$meth_name};
            next unless defined $extra_args;

            # Safety checks against excess binding code or private methods.
            if ( !$method->novel ) {
                confess(  "Binding spec'd for method '$meth_name' in class "
                        . "$class_name, but it's overridden and should be "
                        . "bound in the parent class" );
            }
            elsif ( $method->private ) {
                confess(  "Binding spec'd for method '$meth_name' in class "
                        . "$class_name, but it's private" );
            }

            for my $descendant ( $class->tree_to_ladder ) {
                my $real_method = $descendant->novel_method( lc($meth_name) );
                next unless $real_method;

                # Create the XSub, add it to the list.
                my $xsub = Boilerplater::Binding::Perl::XSub::Method->new(
                    method => $real_method,
                    %$extra_args,
                );
                $xs .= $xsub->xsub_def . "\n";
                push @xsubs, $xsub;
            }
        }

        # Verify that we processed all methods.
        my @leftover_meths = keys %meth_to_bind;
        confess("Leftover for $class_name: '@leftover_meths'")
            if @leftover_meths;
    }

    # Boot XSUBs.
    my @xs_init_lines;
    for my $xsub (@xsubs) {
        my $max_alias_num = $xsub->max_alias_num;
        my $c_name        = $xsub->c_name;
        if ( $max_alias_num > 0 ) {
            for ( 0 .. $max_alias_num ) {
                my $alias = $xsub->full_alias($_);
                next unless $alias;
                push @xs_init_lines, qq|cv = newXS("$alias", $c_name, file);|,
                    qq|XSANY.any_i32 = $_;|;
            }
        }
        else {
            my $perl_name = $xsub->perl_name;
            push @xs_init_lines, qq|newXS("$perl_name", $c_name, file);|;
        }
    }
    my $xs_init = join( "\n        ", @xs_init_lines );

    # Params hashes for arg checking of XSUBs that take labeled params.
    my @params_hash_defs = grep {defined} map { $_->params_hash_def } @xsubs;
    my $params_hash_defs = join( "\n", @params_hash_defs );

    $xs = <<END_STUFF;
#include "xs/XSBind.h"
#include "boil.h"
#include "$self->{boot_h_file}"

#include "KinoSearch/Util/Host.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/StringHelper.h"

#include "Charmonizer/Test.h"
#include "Charmonizer/Test/AllTests.h"

$xs

MODULE = KinoSearch   PACKAGE = KinoSearch::Autobinding

void
init_autobindings()
PPCODE:
{
    char* file = __FILE__;
    CHY_UNUSED_VAR(cv); 
    CHY_UNUSED_VAR(items);
    {
        CV *cv;
        $xs_init;
    }
}

$self->{xs_code}

END_STUFF

    my $pm = <<END_STUFF;
# DO NOT EDIT!!!! This is an auto-generated file.

use strict;
use warnings;

package KinoSearch::Autobinding;

init_autobindings();

$params_hash_defs

1;

END_STUFF

    # Write out if there have been any changes.
    my $xs_path  = $self->{xs_path};
    my $pm_path  = $self->{pm_path};
    my $write_xs = 1;
    my $write_pm = 1;
    if ( -e $xs_path ) {
        open( my $xs_fh, '<', $xs_path )
            or confess("Can't open '$xs_path': $!");
        my $current = do { local $/; <$xs_fh> };
        $write_xs = 0 if $xs eq $current;
    }
    if ( -e $pm_path ) {
        open( my $pm_fh, '<', $pm_path )
            or confess("Can't open '$pm_path': $!");
        my $current = do { local $/; <$pm_fh> };
        $write_pm = 0 if $pm eq $current;
    }
    if ($write_xs) {
        unlink $xs_path;
        sysopen( my $xs_fh, $xs_path, O_CREAT | O_EXCL | O_WRONLY )
            or confess("Can't open '$xs_path': $!");
        print $xs_fh $xs;
    }
    if ($write_pm) {
        unlink $pm_path;
        sysopen( my $pm_fh, $pm_path, O_CREAT | O_EXCL | O_WRONLY )
            or confess("Can't open '$pm_path': $!");
        print $pm_fh $pm;
    }
}

our %write_pod_PARAMS = ( lib_dir => undef, );

sub write_pod {
    my $self = shift;
    verify_args( \%write_pod_PARAMS, @_ ) or confess $@;
    my %args = @_;
    for (qw( lib_dir )) {
        confess "$_ is required" unless $args{$_};
    }
    my @ordered  = $self->{session}->ordered_classes;
    my $make_pod = $self->{make_pod};
    my @files_written;

    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        my $pod_args   = delete $make_pod->{$class_name};
        next unless $pod_args;
        my $pod = _gen_class_pod( $self, $class, $pod_args );

        # Compare against existing file; rewrite if changed.
        my $pod_file_path
            = catfile( $args{lib_dir}, split( '::', $class->get_class_name ) )
            . ".pod";

        $class->file_path( $args{lib_dir}, ".pod" );
        my $existing = "";
        if ( -e $pod_file_path ) {
            open( my $pod_fh, "<", $pod_file_path )
                or confess("Can't open '$pod_file_path': $!");
            $existing = do { local $/; <$pod_fh> };
        }
        if ( $pod ne $existing ) {
            push @files_written, $pod_file_path;
            unlink $pod_file_path;
            sysopen( my $pod_fh, $pod_file_path, O_CREAT | O_EXCL | O_WRONLY )
                or confess("Can't open '$pod_file_path': $!");
            print $pod_fh $pod;
        }
    }
    my @leftover = keys %$make_pod;
    confess("Couldn't match pod to class for '@leftover'") if @leftover;

    return \@files_written;
}

sub _perlify_doc_text {
    my $documentation = shift;

    # Remove double-equals hack needed to fool perldoc, PAUSE, etc. :P
    $documentation =~ s/^==/=/mg;

    # Change <code>foo</code> to C<< foo >>.
    $documentation =~ s#<code>(.*?)</code>#C<< $1 >>#gsm;

    # Lowercase all method names: Open_In() => open_in()
    $documentation
        =~ s/([A-Z][A-Za-z0-9]*(?:_[A-Z][A-Za-z0-9]*)*\(\))/\L$1\E/gsm;

    # Change all instances of NULL to 'undef'
    $documentation =~ s/NULL/undef/g;

    return $documentation;
}

sub _gen_subroutine_pod {
    my ( $self, %args ) = @_;
    my ( $func, $sub_name, $class, $code_sample, $class_name )
        = @args{qw( func name class sample class_name )};
    my $param_list = $func->get_param_list;
    my $args       = "";
    my $num_vars   = $param_list->num_vars;

    # Only allow "public" subs to be exposed as part of the public API.
    confess("$class_name->$sub_name is not public") unless $func->public;

    # Get documentation, which may be inherited.
    my $docucom = $func->get_docu_comment;
    if ( !$docucom ) {
        my $micro_sym = $func->micro_sym;
        my $parent    = $class;
        while ( $parent = $parent->get_parent ) {
            my $parent_func = $parent->method($micro_sym);
            last unless $parent_func;
            $docucom = $parent_func->get_docu_comment;
            last if $docucom;
        }
    }
    confess("No DocuComment for '$sub_name' in '$class_name'")
        unless $docucom;

    if ( $num_vars > 2 or ( $args{is_constructor} && $num_vars > 1 ) ) {
        $args = " I<[labeled params]> ";
    }
    elsif ( $param_list->num_vars ) {
        $args = $func->get_param_list->name_list;
        $args =~ s/self.*?(?:,\s*|$)//;    # kill self param
    }

    my $pod = "=head2 $sub_name($args)\n\n";
    if ( defined($code_sample) && length($code_sample) ) {
        $pod .= "$code_sample\n";
    }
    if ( my $full_doc = $docucom->get_full ) {
        $pod .= _perlify_doc_text($full_doc) . "\n\n";
    }

    # Add params in a list.
    my $param_names = $docucom->get_param_names;
    my $param_docs  = $docucom->get_param_docs;
    if (@$param_names) {
        $pod .= "=over\n\n";
        for ( my $i = 0; $i <= $#$param_names; $i++ ) {
            $pod .= "=item *\n\n";
            $pod .= "B<$param_names->[$i]> - $param_docs->[$i]\n\n";
        }
        $pod .= "=back\n\n";
    }

    # Add return value description, if any.
    if ( defined( my $retval = $docucom->get_retval ) ) {
        $pod .= "Returns: $retval\n\n";
    }

    return $pod;
}

sub _gen_class_pod {
    my ( $self, $class, $pod_args ) = @_;
    my $class_name = $class->get_class_name;
    my $docucom    = $class->get_docu_comment;
    confess("No DocuComment for '$class_name'") unless $docucom;
    my $brief       = $docucom->get_brief;
    my $description = _perlify_doc_text( $pod_args->{description}
            || $docucom->get_description );

    my $synopsis_pod = '';
    if ( defined $pod_args->{synopsis} ) {
        $synopsis_pod = qq|=head1 SYNOPSIS\n\n$pod_args->{synopsis}\n|;
    }

    my $constructor_pod = "";
    my $constructors = $pod_args->{constructors} || [];
    if ( defined $pod_args->{constructor} ) {
        push @$constructors, $pod_args->{constructor};
    }
    if (@$constructors) {
        $constructor_pod = "=head1 CONSTRUCTORS\n\n";
        for my $spec (@$constructors) {
            if ( !ref $spec ) {
                $constructor_pod .= _perlify_doc_text($spec);
            }
            else {
                my $func_name   = $spec->{func} || 'init';
                my $init_func   = $class->function($func_name);
                my $ctor_name   = $spec->{name} || 'new';
                my $code_sample = $spec->{sample};
                $constructor_pod .= _perlify_doc_text(
                    $self->_gen_subroutine_pod(
                        func           => $init_func,
                        name           => $ctor_name,
                        sample         => $code_sample,
                        class          => $class,
                        class_name     => $class_name,
                        is_constructor => 1,
                    )
                );
            }
        }
    }

    my @method_docs;
    my $methods_pod = "";
    my @abstract_method_docs;
    my $abstract_methods_pod = "";
    for my $spec ( @{ $pod_args->{methods} } ) {
        my $meth_name = ref($spec) ? $spec->{name} : $spec;
        my $method = $class->method($meth_name);
        confess("Can't find method '$meth_name' in class '$class_name'")
            unless $method;
        my $method_pod;
        if ( ref($spec) ) {
            $method_pod = $spec->{pod};
        }
        else {
            $method_pod = $self->_gen_subroutine_pod(
                func       => $method,
                name       => $meth_name,
                sample     => '',
                class      => $class,
                class_name => $class_name
            );
        }
        if ( $method->abstract ) {
            push @abstract_method_docs, _perlify_doc_text($method_pod);
        }
        else {
            push @method_docs, _perlify_doc_text($method_pod);
        }
    }
    if (@method_docs) {
        $methods_pod = join( "", "=head1 METHODS\n\n", @method_docs );
    }
    if (@abstract_method_docs) {
        $abstract_methods_pod = join( "", "=head1 ABSTRACT METHODS\n\n",
            @abstract_method_docs );
    }

    my $child = $class;
    my @ancestors;
    while ( defined( my $parent = $child->get_parent ) ) {
        push @ancestors, $parent;
        $child = $parent;
    }
    my $inheritance_pod = "";
    if (@ancestors) {
        $inheritance_pod = "=head1 INHERITANCE\n\n";
        $inheritance_pod .= $class->get_class_name;
        for my $ancestor (@ancestors) {
            $inheritance_pod .= " isa L<" . $ancestor->get_class_name . ">";
        }
        $inheritance_pod .= ".\n";
    }

    my $pod = <<END_POD;

# Auto-generated file -- DO NOT EDIT!!!!!

=head1 NAME

$class_name - $brief

$synopsis_pod

=head1 DESCRIPTION

$description

$constructor_pod

$methods_pod

$abstract_methods_pod

$inheritance_pod

=head1 COPYRIGHT AND LICENSE

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

END_POD

}

# Write out boot.h and boot.c files, which contain code for
# bootstrapping Boilerplater classes.
sub write_boot {
    my $self = shift;
    $self->_write_boot_h;
    $self->_write_boot_c;
}

sub _write_boot_h {
    my $self     = shift;
    my $session  = $self->{session};
    my $header   = $session->get_header;
    my $footer   = $session->get_footer;
    my $filepath = catfile( $session->get_dest_dir, $self->{boot_h_file} );
    my $guard    = uc("$self->{boot_class}_BOOT");
    $guard =~ s/\W+/_/g;

    unlink $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
        or confess("Can't open '$filepath': $!");
    print $fh <<END_STUFF;
$header

#ifndef $guard
#define $guard 1

void
$self->{boot_func}();

#endif /* $guard */

$footer
END_STUFF
}

sub _write_boot_c {
    my $self           = shift;
    my $session        = $self->{session};
    my $header         = $session->get_header;
    my $footer         = $session->get_footer;
    my @ordered        = $session->ordered_classes;
    my $num_classes    = scalar @ordered;
    my $pound_includes = "";
    my $registrations  = "";
    my $isa_pushes     = "";

    for my $class (@ordered) {
        my $include_h = $class->include_h;
        $pound_includes .= qq|#include "$include_h"\n|;
        next if $class->inert;
        my $prefix  = $class->get_prefix;
        my $PREFIX  = $class->get_PREFIX;
        my $vt_type = $PREFIX . $class->vtable_type;
        $registrations
            .= qq|    ${prefix}VTable_add_to_registry($PREFIX|
            . $class->vtable_var
            . qq|);\n|;

        my $parent = $class->get_parent;
        next unless $parent;
        my $parent_class = $parent->get_class_name;
        my $class_name   = $class->get_class_name;
        $isa_pushes .= qq|    isa = get_av("$class_name\::ISA", 1);\n|;
        $isa_pushes .= qq|    av_push(isa, newSVpv("$parent_class", 0));\n|;
    }
    my $filepath = catfile( $session->get_dest_dir, $self->{boot_c_file} );
    unlink $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
        or confess("Can't open '$filepath': $!");
    print $fh <<END_STUFF;
$header

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "$self->{boot_h_file}"
#include "boil.h"
$pound_includes

void
$self->{boot_func}()
{
    AV *isa;
$registrations
$isa_pushes
}

$footer

END_STUFF
}

1;
