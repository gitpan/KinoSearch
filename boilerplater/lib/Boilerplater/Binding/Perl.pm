use strict;
use warnings;

package Boilerplater::Binding::Perl;

use Boilerplater::Hierarchy;
use Carp;
use File::Spec::Functions qw( catfile );
use Fcntl;

use Boilerplater::Class;
use Boilerplater::Function;
use Boilerplater::Method;
use Boilerplater::Variable;
use Boilerplater::Util qw( verify_args write_if_changed );
use Boilerplater::Binding::Perl::Class;
use Boilerplater::Binding::Perl::Method;
use Boilerplater::Binding::Perl::Constructor;

our %new_PARAMS = (
    hierarchy   => undef,
    xs_path     => undef,
    pm_path     => undef,
    boot_class  => undef,
    boot_h_file => undef,
    boot_c_file => undef,
    boot_func   => undef,
    header      => '',
    footer      => '',
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, ref($either) || $either;
    for ( keys %new_PARAMS ) {
        confess("$_ is mandatory") unless defined $self->{$_};
    }
    return $self;
}

sub write_bindings {
    my $self     = shift;
    my @ordered  = $self->{hierarchy}->ordered_classes;
    my $registry = Boilerplater::Binding::Perl::Class->registry;
    my $hand_rolled_xs = "";
    my $generated_xs   = "";
    my $xs       = "";
    my @xsubs;

    # Build up a roster of all requested bindings.
    my %has_constructors;
    my %has_methods;
    my %has_xs_code;
    while ( my ( $class_name, $class_binding ) = each %$registry ) {
        $has_constructors{$class_name} = 1
            if $class_binding->get_bind_constructors;
        $has_methods{$class_name} = 1
            if $class_binding->get_bind_methods;
        $has_xs_code{$class_name} = 1
            if $class_binding->get_xs_code;
    }

    # Pound-includes for generated headers.
    for my $class (@ordered) {
        my $include_h = $class->include_h;
        $generated_xs .= qq|#include "$include_h"\n|;
    }
    $generated_xs .= "\n";

    # Constructors.
    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        next unless delete $has_constructors{$class_name};
        my $class_binding = $registry->{$class_name};
        my @bound         = $class_binding->constructor_bindings;
        $generated_xs .= $_->xsub_def . "\n" for @bound;
        push @xsubs, @bound;
    }

    # Methods.
    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        next unless delete $has_methods{$class_name};
        my $class_binding = $registry->{$class_name};
        my @bound         = $class_binding->method_bindings;
        $generated_xs .= $_->xsub_def . "\n" for @bound;
        push @xsubs, @bound;
    }

    # Hand-rolled XS.
    for my $class_name ( keys %has_xs_code ) {
        my $class_binding = $registry->{$class_name};
        $hand_rolled_xs .= $class_binding->get_xs_code . "\n";
    }
    %has_xs_code = ();

    # Verify that all binding specs were processed.
    my @leftover_ctor = keys %has_constructors;
    if (@leftover_ctor) {
        confess(  "Constructor bindings spec'd for non-existant classes: "
                . "'@leftover_ctor'" );
    }
    my @leftover_bound = keys %has_methods;
    if (@leftover_bound) {
        confess(  "Method bindings spec'd for non-existant classes: "
                . "'@leftover_bound'" );
    }
    my @leftover_xs = keys %has_xs_code;
    if (@leftover_xs) {
        confess(  "Hand-rolled XS spec'd for non-existant classes: "
                . "'@leftover_xs'" );
    }

    # Build up code for booting XSUBs at module load time.
    my @xs_init_lines;
    for my $xsub (@xsubs) {
        my $c_name    = $xsub->c_name;
        my $perl_name = $xsub->perl_name;
        push @xs_init_lines, qq|newXS("$perl_name", $c_name, file);|;
    }
    my $xs_init = join( "\n    ", @xs_init_lines );

    # Params hashes for arg checking of XSUBs that take labeled params.
    my @params_hash_defs = grep {defined} map { $_->params_hash_def } @xsubs;
    my $params_hash_defs = join( "\n", @params_hash_defs );

    # Write out if there have been any changes.
    my $xs_file_contents = $self->_xs_file_contents( $generated_xs, $xs_init,
        $hand_rolled_xs );
    my $pm_file_contents = $self->_pm_file_contents($params_hash_defs);
    write_if_changed( $self->{xs_path}, $xs_file_contents );
    write_if_changed( $self->{pm_path}, $pm_file_contents );
}

sub _xs_file_contents {
    my ( $self, $generated_xs, $xs_init, $hand_rolled_xs ) = @_;
    return <<END_STUFF;
#define C_KINO_ZOMBIECHARBUF
#include "xs/XSBind.h"
#include "boil.h"
#include "$self->{boot_h_file}"

#include "KinoSearch/Util/Host.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/StringHelper.h"

#include "Charmonizer/Test.h"
#include "Charmonizer/Test/AllTests.h"

$generated_xs

MODULE = KinoSearch   PACKAGE = KinoSearch::Autobinding

void
init_autobindings()
PPCODE:
{
    char* file = __FILE__;
    CHY_UNUSED_VAR(cv); 
    CHY_UNUSED_VAR(items);
    $xs_init
}

$hand_rolled_xs

END_STUFF
}

sub _pm_file_contents {
    my ( $self, $params_hash_defs ) = @_;
    return <<END_STUFF;
# DO NOT EDIT!!!! This is an auto-generated file.

use strict;
use warnings;

package KinoSearch::Autobinding;

init_autobindings();

$params_hash_defs

1;

END_STUFF
}

our %prepare_pod_PARAMS = ( lib_dir => undef, );

sub prepare_pod {
    my $self = shift;
    verify_args( \%prepare_pod_PARAMS, @_ ) or confess $@;
    my %args    = @_;
    my $lib_dir = $args{lib_dir}
        or confess("Missing required param 'lib_dir'");
    for (qw( lib_dir )) {
        confess "$_ is required" unless $args{$_};
    }
    my @ordered = $self->{hierarchy}->ordered_classes;
    my @files_written;
    my %has_pod;
    my %modified;

    my $registry = Boilerplater::Binding::Perl::Class->registry;
    $has_pod{ $_->get_class_name } = 1
        for grep { $_->get_make_pod } values %$registry;

    for my $class (@ordered) {
        my $class_name = $class->get_class_name;
        my $class_binding = $registry->{$class_name} or next;
        next unless delete $has_pod{$class_name};
        my $pod = $class_binding->create_pod;
        confess("Failed to generate POD for $class_name") unless $pod;

        # Compare against existing file; rewrite if changed.
        my $pod_file_path
            = catfile( $args{lib_dir}, split( '::', $class_name ) ) . ".pod";

        $class->file_path( $args{lib_dir}, ".pod" );
        my $existing = "";
        if ( -e $pod_file_path ) {
            open( my $pod_fh, "<", $pod_file_path )
                or confess("Can't open '$pod_file_path': $!");
            $existing = do { local $/; <$pod_fh> };
        }
        if ( $pod ne $existing ) {
            $modified{$pod_file_path} = $pod;
        }
    }
    my @leftover = keys %has_pod;
    confess("Couldn't match pod to class for '@leftover'") if @leftover;

    return \%modified;
}

# Write out boot.h and boot.c files, which contain code for
# bootstrapping Boilerplater classes.
sub write_boot {
    my $self = shift;
    $self->_write_boot_h;
    $self->_write_boot_c;
}

sub _write_boot_h {
    my $self      = shift;
    my $hierarchy = $self->{hierarchy};
    my $filepath  = catfile( $hierarchy->get_dest, $self->{boot_h_file} );
    my $guard     = uc("$self->{boot_class}_BOOT");
    $guard =~ s/\W+/_/g;

    unlink $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
        or confess("Can't open '$filepath': $!");
    print $fh <<END_STUFF;
$self->{header}

#ifndef $guard
#define $guard 1

void
$self->{boot_func}();

#endif /* $guard */

$self->{footer}
END_STUFF
}

sub _write_boot_c {
    my $self           = shift;
    my $hierarchy      = $self->{hierarchy};
    my @ordered        = $hierarchy->ordered_classes;
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
    my $filepath = catfile( $hierarchy->get_dest, $self->{boot_c_file} );
    unlink $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
        or confess("Can't open '$filepath': $!");
    print $fh <<END_STUFF;
$self->{header}

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

$self->{footer}

END_STUFF
}

sub write_xs_typemap {
    my $self = shift;
    Boilerplater::Binding::Perl::TypeMap->write_xs_typemap(
        hierarchy => $self->{hierarchy}, );
}

1;
