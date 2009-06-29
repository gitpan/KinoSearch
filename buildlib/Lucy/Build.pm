use strict;
use warnings;

use lib '../boilerplater/lib';
use lib 'boilerplater/lib';

package Lucy::Build::CBuilder;
BEGIN { our @ISA = "ExtUtils::CBuilder"; }
use Config;

sub new {
    my $class = shift;
    require ExtUtils::CBuilder;
    return $class->SUPER::new(@_);
}

# This method isn't implemented by CBuilder for Windows, so we issue a basic
# link command that works on at least one system and hope for the best.
sub link_executable {
    my ( $self, %args ) = @_;
    if ( $Config{cc} eq 'cl' ) {
        my ( $objects, $exe_file ) = @args{qw( objects exe_file )};
        $self->do_system("link /out:$exe_file @$objects");
        return $exe_file;
    }
    else {
        return $self->SUPER::link_executable(%args);
    }
}

package Lucy::Build;
use base qw( Module::Build );

use File::Spec::Functions
    qw( catdir catfile curdir splitpath updir no_upwards );
use File::Path qw( mkpath rmtree );
use File::Copy qw( copy move );
use File::Find qw( find );
use Config;
use Env qw( @PATH );
use Fcntl;
use Carp;

unshift @PATH, curdir();

=for Rationale

When the distribution tarball for the Perl binding of Lucy is built, core/,
charmonizer/, and any other needed files/directories are copied into the
perl/ directory within the main Lucy directory.  Then the distro is built from
the contents of the perl/ directory, leaving out all the files in ruby/, etc.
However, during development, the files are accessed from their original
locations.

=cut

my $is_distro_not_devel = -e 'core';
my $base_dir = $is_distro_not_devel ? curdir() : updir();

my $CHARMONIZE_EXE_PATH  = 'charmonize' . $Config{_exe};
my $CHARMONIZER_ORIG_DIR = catdir( $base_dir, 'charmonizer' );
my $CHARMONIZER_GEN_DIR  = catdir( $CHARMONIZER_ORIG_DIR, 'gen' );
my $CORE_SOURCE_DIR      = catdir( $base_dir, 'core' );
my $AUTOGEN_DIR          = 'autogen';
my $XS_SOURCE_DIR        = 'xs';
my $AUTOBIND_PM_PATH     = catfile(qw( lib KinoSearch Autobinding.pm ));
my $AUTOBIND_XS_PATH     = catfile(qw( lib KinoSearch Autobinding.xs ));

my $EXTRA_CCFLAGS = '';
if ( defined $ENV{LUCY_DEBUG} || defined $ENV{KINO_DEBUG} ) {
    $EXTRA_CCFLAGS .= "-DKINO_DEBUG ";
    # allow override when Perl was compiled with an older version
    my $gcc_version = $ENV{REAL_GCC_VERSION} || $Config{gccversion};
    if ( defined $gcc_version ) {
        $gcc_version =~ /^(\d+(\.\d+)?)/ or die "no match";
        $gcc_version = $1;
        $EXTRA_CCFLAGS .= "-DPERL_GCC_PEDANTIC -ansi -pedantic -Wall "
            . "-std=c89 -Wno-long-long ";
        $EXTRA_CCFLAGS .= "-Wextra " if $gcc_version >= 3.4;    # correct
        $EXTRA_CCFLAGS .= "-Wno-variadic-macros "
            if $gcc_version > 3.4;    # at least not on gcc 3.4
    }
}
my $VALGRIND = $ENV{CHARM_VALGRIND} ? "valgrind --leak-check=yes " : "";

=begin comment

Lucy::Build serves double duty as a build tool for both Lucy and KinoSearch,
in order to facilitate synchronization.

Since they will never be built at the same time, and since Module::Build pulls
some hocus pocus when creating objects that is difficult to control, we set a
few class variables rather than use instance variables to adapt the behavior
to one or the other.  

=end comment
=cut

my $XS_FILEPATH = 'Lucy.xs';
my ( $PREFIX, $Prefix, $prefix ) = qw( LUCY_ Lucy_ lucy_ );
my $kino_or_lucy = 'lucy';

sub use_kinosearch_mode {
    $XS_FILEPATH = 'KinoSearch.xs';
    ( $PREFIX, $Prefix, $prefix ) = qw( KINO_ Kino_ kino_ );
    $kino_or_lucy = 'kino';
}

sub new {
    return shift->SUPER::new( recursive_test_files => 1, @_ );
}

# Collect all relevant Charmonizer files.
sub ACTION_metaquote {
    my $self          = shift;
    my $charm_src_dir = catdir( $CHARMONIZER_ORIG_DIR, 'src' );
    my $orig_files    = $self->rscan_dir( $charm_src_dir, qr/\.c?harm$/ );
    my $dest_files    = $self->rscan_dir( $CHARMONIZER_GEN_DIR, qr/\.[ch]$/ );
    push @$dest_files, $CHARMONIZER_GEN_DIR;
    if ( !$self->up_to_date( $orig_files, $dest_files ) ) {
        mkpath $CHARMONIZER_GEN_DIR unless -d $CHARMONIZER_GEN_DIR;
        $self->add_to_cleanup($CHARMONIZER_GEN_DIR);
        my $metaquote = catfile( $CHARMONIZER_ORIG_DIR, qw( bin metaquote ) );
        my $command = "$^X $metaquote --src=$charm_src_dir "
            . "--out=$CHARMONIZER_GEN_DIR";
        system($command);
    }
}

# Build the charmonize executable.
sub ACTION_charmonizer {
    my $self = shift;
    $self->dispatch('metaquote');

    # Gather .c and .h Charmonizer files.
    my $charm_source_files
        = $self->rscan_dir( $CHARMONIZER_GEN_DIR, qr/Charmonizer.+\.[ch]$/ );
    my $charmonize_c = catfile( $CHARMONIZER_ORIG_DIR, 'charmonize.c' );
    my @all_source = ( $charmonize_c, @$charm_source_files );

    # Don't compile if we're up to date.
    return if $self->up_to_date( \@all_source, $CHARMONIZE_EXE_PATH );

    print "Building $CHARMONIZE_EXE_PATH...\n\n";

    my $cbuilder = Lucy::Build::CBuilder->new;

    my @o_files;
    for (@all_source) {
        next unless /\.c$/;
        next if m#Charmonizer/Test#;
        my $o_file = $cbuilder->object_file($_);
        $self->add_to_cleanup($o_file);
        push @o_files, $o_file;

        next if $self->up_to_date( $_, $o_file );

        $cbuilder->compile(
            source               => $_,
            include_dirs         => [$CHARMONIZER_GEN_DIR],
            extra_compiler_flags => $EXTRA_CCFLAGS,
        );
    }

    $self->add_to_cleanup($CHARMONIZE_EXE_PATH);
    my $exe_path = $cbuilder->link_executable(
        objects  => \@o_files,
        exe_file => $CHARMONIZE_EXE_PATH,
    );
}

# Run the charmonizer executable, creating the charmony.h file.
sub ACTION_charmony {
    my $self          = shift;
    my $charmony_in   = 'charmony_in';
    my $charmony_path = 'charmony.h';

    $self->dispatch('charmonizer');

    return if $self->up_to_date( $CHARMONIZE_EXE_PATH, $charmony_path );
    print "\nWriting $charmony_path...\n\n";

    # Clean up after Charmonizer if it doesn't succeed on its own.
    $self->add_to_cleanup("_charm*");

    # Write the infile with which to communicate args to charmonize.
    my $os_name   = lc( $Config{osname} );
    my $flags     = "$Config{ccflags} $EXTRA_CCFLAGS";
    my $verbosity = $ENV{DEBUG_CHARM} ? 2 : 1;
    my $cc        = "$Config{cc}";
    unlink $charmony_in;
    $self->add_to_cleanup( $charmony_path, $charmony_in );
    sysopen( my $infile_fh, $charmony_in, O_CREAT | O_WRONLY | O_EXCL )
        or die "Can't open '$charmony_in': $!";
    print $infile_fh qq|
        <charm_os_name>$os_name</charm_os_name>
        <charm_cc_command>$cc</charm_cc_command>
        <charm_cc_flags>$flags</charm_cc_flags>
        <charm_verbosity>$verbosity</charm_verbosity>
    |;
    close $infile_fh or die "Can't close '$charmony_in': $!";

    if ($VALGRIND) {
        system("$VALGRIND ./$CHARMONIZE_EXE_PATH $charmony_in")
            and die "Failed to write charmony.h";
    }
    else {
        system( $CHARMONIZE_EXE_PATH, $charmony_in )
            and die "Failed to write charmony.h";
    }
}

sub _compile_boilerplater {
    my $self = shift;

    my $xs_code = "";
    my %auto_xs;

    require Boilerplater::Session;
    require Boilerplater::Binding::Perl;

    # Concatenate all XS frags, process all AUTO_XS blocks.
    my $pm_filepaths = $self->rscan_dir( 'lib', qr/\.pm$/ );
    my @pm_filepaths_with_xs;
    for my $pm_filepath (@$pm_filepaths) {
        open( my $pm_fh, '<', $pm_filepath )
            or die "Can't open '$pm_filepath': $!";
        my $pm_content = do { local $/; <$pm_fh> };
        my ($xs_frag) = $pm_content =~ /^__XS__\s*(.*?)(?:^__\w+__|\Z)/sm;
        if ($xs_frag) {
            $xs_code .= $xs_frag;
        }
        my ($auto_xs_frag)
            = $pm_content =~ /^__AUTO_XS__\s*(.*?)(?:^__\w+__|\Z)/sm;
        if ($auto_xs_frag) {
            my $to_bind = eval $auto_xs_frag;
            confess("invalid __AUTO_XS__ from $pm_filepath: $@")
                unless ref($to_bind) eq 'HASH';
            while ( my ( $class, $directives ) = each %$to_bind ) {
                confess "$class already registered"
                    if defined $auto_xs{$class};
                $auto_xs{$class} = $directives;
            }
        }

        if ( $xs_frag || $auto_xs_frag ) {
            push @pm_filepaths_with_xs, $pm_filepath;
        }
    }

    my $session = Boilerplater::Session->new(
        base_dir => $CORE_SOURCE_DIR,
        dest_dir => $AUTOGEN_DIR,
        header   => $self->autogen_header,
        footer   => $self->copyfoot,
    );
    $session->build;

    my $binding = Boilerplater::Binding::Perl->new(
        session     => $session,
        pm_path     => $AUTOBIND_PM_PATH,
        xs_path     => $XS_FILEPATH,
        xs_code     => $xs_code,
        boot_class  => 'KinoSearch',
        boot_func   => $kino_or_lucy . "_Boot_bootstrap",
        boot_h_file => $kino_or_lucy . "_boot.h",
        boot_c_file => $kino_or_lucy . "_boot.c",
    );
    while ( my ( $class_name, $lists ) = each %auto_xs ) {
        $binding->add_class( class_name => $class_name, %$lists );
    }

    return ( $session, $binding, \@pm_filepaths_with_xs );
}

sub ACTION_pod { shift->_write_pod(@_) }

sub _write_pod {
    my ( $self, $binding ) = @_;
    if ( !$binding ) {
        ( undef, $binding ) = $self->_compile_boilerplater;
    }
    my $pod_files = $binding->write_pod( lib_dir => 'lib' );
    $self->add_to_cleanup(@$pod_files);
}

sub ACTION_boilerplater {
    my $self = shift;

    $self->dispatch('charmony');

    # Create destination dir, copy xs helper files.
    if ( !-d $AUTOGEN_DIR ) {
        mkdir $AUTOGEN_DIR or die "Can't mkdir '$AUTOGEN_DIR': $!";
    }
    $self->add_to_cleanup($AUTOGEN_DIR);

    my $pm_filepaths = $self->rscan_dir( 'lib',            qr/\.pm$/ );
    my $bp_filepaths = $self->rscan_dir( $CORE_SOURCE_DIR, qr/\.bp$/ );

    # Don't bother parsing Boilerplater files if everything's up to date.
    return
        if $self->up_to_date(
        [ @$bp_filepaths, @$pm_filepaths ],
        [ $XS_FILEPATH,   $AUTOGEN_DIR, ]
        );

    # Write out all autogenerated files.
    my ( $session, $binding, $pm_filepaths_with_xs )
        = $self->_compile_boilerplater;
    my $modified = $session->write_all_modified;
    $session->write_boil_h if $modified;

    # Rewrite XS if either any .bp files or relevant .pm files were modified.
    $modified ||=
        $self->up_to_date( \@$pm_filepaths_with_xs, $XS_FILEPATH )
        ? 0
        : 1;

    if ($modified) {
        $self->add_to_cleanup($XS_FILEPATH);
        $self->add_to_cleanup($AUTOBIND_PM_PATH);
        $binding->write_boot;
        $binding->write_bindings;
        $self->_write_pod($binding);
    }

    # Touch autogenerated files in case the modifications were inconsequential
    # and didn't trigger a rewrite, so that we won't have to check them again
    # next pass.
    if (!$self->up_to_date(
            [ @$bp_filepaths, @$pm_filepaths_with_xs ], $XS_FILEPATH
        )
        )
    {
        utime( time, time, $XS_FILEPATH );    # touch
    }
    if (!$self->up_to_date(
            [ @$bp_filepaths, @$pm_filepaths_with_xs ], $AUTOGEN_DIR
        )
        )
    {
        utime( time, time, $AUTOGEN_DIR );    # touch
    }
}

sub ACTION_suppressions {
    my $self       = shift;
    my $LOCAL_SUPP = 'local.supp';
    return if $self->up_to_date( 't/valgrind_triggers.pl', $LOCAL_SUPP );

    # Generate suppressions.
    print "Writing $LOCAL_SUPP...\n";
    $self->add_to_cleanup($LOCAL_SUPP);
    my $command
        = "yes | "
        . $self->_valgrind_base_command
        . "--gen-suppressions=yes "
        . $self->perl
        . " t/valgrind_triggers.pl 2>&1";
    my $suppressions = `$command`;
    $suppressions =~ s/^==.*?\n//mg;
    my $rule_number = 1;
    while ( $suppressions =~ /<insert a.*?>/ ) {
        $suppressions =~ s/^\s*<insert a.*?>/{\n  <core_perl_$rule_number>/m;
        $rule_number++;
    }

    # Write local suppressions file.
    open( my $supp_fh, '>', $LOCAL_SUPP )
        or confess("Can't open '$LOCAL_SUPP': $!");
    print $supp_fh $suppressions;
}

sub _valgrind_base_command {
    return
          "PERL_DESTRUCT_LEVEL=2 KINO_VALGRIND=1 valgrind "
        . "--leak-check=yes "
        . "--show-reachable=yes "
        . "--num-callers=10 "
        . "--suppressions=../devel/conf/kinoperl.supp ";
}

sub ACTION_test_valgrind {
    my $self = shift;
    die "Must be run under a perl that was compiled with -DDEBUGGING"
        unless $Config{ccflags} =~ /-D?DEBUGGING\b/;
    $self->dispatch('code');
    $self->dispatch('suppressions');

    # Unbuffer STDOUT, grab test file names and suppressions files.
    $|++;
    my $t_files = $self->find_test_files;    # not public M::B API, may fail
    my $valgrind_command = $self->_valgrind_base_command;
    $valgrind_command .= "--suppressions=local.supp ";

    if ( my $local_supp = $self->args('suppressions') ) {
        for my $supp ( split( ',', $local_supp ) ) {
            $valgrind_command .= "--suppressions=$supp ";
        }
    }

    # Iterate over test files.
    my @failed;
    for my $t_file (@$t_files) {

        # Run test file under Valgrind.
        print "Testing $t_file...";
        die "Can't find '$t_file'" unless -f $t_file;
        my $command = "$valgrind_command $^X -Mblib $t_file 2>&1";
        my $output = "\n" . ( scalar localtime(time) ) . "\n$command\n";
        $output .= `$command`;

        # Screen-scrape Valgrind output, looking for errors and leaks.
        if (   $?
            or $output =~ /ERROR SUMMARY:\s+[^0\s]/
            or $output =~ /definitely lost:\s+[^0\s]/
            or $output =~ /possibly lost:\s+[^0\s]/
            or $output =~ /still reachable:\s+[^0\s]/ )
        {
            print " failed.\n";
            push @failed, $t_file;
            print "$output\n";
        }
        else {
            print " succeeded.\n";
        }
    }

    # If there are failed tests, print a summary list.
    if (@failed) {
        print "\nFailed "
            . scalar @failed . "/"
            . scalar @$t_files
            . " test files:\n    "
            . join( "\n    ", @failed ) . "\n";
        exit(1);
    }
}

sub ACTION_compile_custom_xs {
    my $self = shift;
    require ExtUtils::ParseXS;

    my $cbuilder = Lucy::Build::CBuilder->new;
    my $archdir = catdir( $self->blib, 'arch', 'auto', 'KinoSearch' );
    mkpath( $archdir, 0, 0777 ) unless -d $archdir;
    my @include_dirs = (
        curdir(), $CORE_SOURCE_DIR, $AUTOGEN_DIR, $XS_SOURCE_DIR,
        $CHARMONIZER_GEN_DIR,
    );
    my @objects;

    # Compile C source files.
    my $c_files = $self->rscan_dir( $CORE_SOURCE_DIR, qr/\.c$/ );
    push @$c_files, @{ $self->rscan_dir( $XS_SOURCE_DIR,       qr/\.c$/ ) };
    push @$c_files, @{ $self->rscan_dir( $CHARMONIZER_GEN_DIR, qr/\.c$/ ) };
    push @$c_files, @{ $self->rscan_dir( $AUTOGEN_DIR,         qr/\.c$/ ) };
    for my $c_file (@$c_files) {
        my $o_file = $c_file;
        $o_file =~ s/\.c/$Config{_o}/;
        push @objects, $o_file;
        next if $self->up_to_date( $c_file, $o_file );
        $self->add_to_cleanup($o_file);
        $cbuilder->compile(
            source               => $c_file,
            extra_compiler_flags => $EXTRA_CCFLAGS,
            include_dirs         => \@include_dirs,
            object_file          => $o_file,
        );
    }

    # .xs => .c
    my $ks_c_file = 'KinoSearch.c';
    $self->add_to_cleanup($ks_c_file);
    if ( !$self->up_to_date( $XS_FILEPATH, $ks_c_file ) ) {
        ExtUtils::ParseXS::process_file(
            filename   => $XS_FILEPATH,
            prototypes => 0,
            output     => $ks_c_file,
        );
    }

    # .c => .o
    my $version   = $self->dist_version;
    my $ks_o_file = "KinoSearch$Config{_o}";
    unshift @objects, $ks_o_file;
    $self->add_to_cleanup($ks_o_file);
    if ( !$self->up_to_date( $ks_c_file, $ks_o_file ) ) {
        $cbuilder->compile(
            source               => $ks_c_file,
            extra_compiler_flags => $EXTRA_CCFLAGS,
            include_dirs         => \@include_dirs,
            object_file          => $ks_o_file,
            # 'defines' is an undocumented parameter to compile(), so we
            # should officially roll our own variant and generate compiler
            # flags.  However, that involves writing a bunch of
            # platform-dependent code, so we'll just take the chance that this
            # will break.
            defines => {
                VERSION    => qq|"$version"|,
                XS_VERSION => qq|"$version"|,
            },
        );
    }

    # Create .bs bootstrap file, needed by Dynaloader.
    my $ks_bs_file = catfile( $archdir, 'KinoSearch.bs' );
    $self->add_to_cleanup($ks_bs_file);
    if ( !$self->up_to_date( $ks_o_file, $ks_bs_file ) ) {
        require ExtUtils::Mkbootstrap;
        ExtUtils::Mkbootstrap::Mkbootstrap($ks_bs_file);
        if ( !-f $ks_bs_file ) {
            # Create file in case Mkbootstrap didn't do anything.
            open( my $fh, '>', $ks_bs_file )
                or confess "Can't open $ks_bs_file: $!";
        }
        utime( (time) x 2, $ks_bs_file );    # touch
    }

    # .o => .(a|bundle)
    my $ks_lib_file = catfile( $archdir, "KinoSearch.$Config{dlext}" );
    if ( !$self->up_to_date( [ @objects, $AUTOGEN_DIR ], $ks_lib_file ) ) {
        $cbuilder->link(
            module_name => 'KinoSearch',
            objects     => \@objects,
            lib_file    => $ks_lib_file,
        );
    }
}

sub ACTION_code {
    my $self = shift;

    $self->dispatch('boilerplater');
    $self->dispatch('write_typemap');
    $self->dispatch('compile_custom_xs');

    $self->SUPER::ACTION_code;
}

# Copied from Module::Build::Base.pm, added exclude '#' and follow symlinks.
sub rscan_dir {
    my ( $self, $dir, $pattern ) = @_;
    my @result;
    local $_;    # find() can overwrite $_, so protect ourselves
    my $subr
        = !$pattern ? sub { push @result, $File::Find::name }
        : !ref($pattern)
        || ( ref $pattern eq 'Regexp' )
        ? sub { push @result, $File::Find::name if /$pattern/ }
        : ref($pattern) eq 'CODE'
        ? sub { push @result, $File::Find::name if $pattern->() }
        : die "Unknown pattern type";

    File::Find::find( { wanted => $subr, no_chdir => 1, follow => 1 }, $dir );

    # Skip emacs lock files.
    my @filtered = grep !/#/, @result;
    return \@filtered;
}

sub autogen_header {
    my $self = shift;
    return <<"END_AUTOGEN";
/***********************************************

 !!!! DO NOT EDIT !!!!

 This file was auto-generated by Build.PL.

 ***********************************************/

END_AUTOGEN
}

sub copyfoot {

    if ( $kino_or_lucy eq 'kino' ) {
        return <<END_COPYFOOT;
/* Copyright 2008-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
END_COPYFOOT
    }
    else {
        return <<END_COPYFOOT;
/**
 * Copyright 2008 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
END_COPYFOOT
    }
}

=for Rationale

All of our C-struct types share the same typemap profile, but can't be mapped
to a single type.  Instead of tediously hand-editing the typemap file, we
autogenerate the file. 

=cut

# Write the typemap file.
sub ACTION_write_typemap {
    my $self = shift;

    my $pm_filepaths = $self->rscan_dir( 'lib', qr/\.pm$/ );
    return
        if ( -e 'typemap' and $self->up_to_date( $pm_filepaths, 'typemap' ) );

    # Build up a list of C-struct classes.
    my @struct_classes;
    my $bp_filepaths = $self->rscan_dir( $CORE_SOURCE_DIR, qr/\.bp$/ );
    for my $bp_path (@$bp_filepaths) {
        open( my $bp_fh, '<', $bp_path ) or die "Can't open '$bp_path': $!";
        my $content = do { local $/; <$bp_fh> };
        while ( $content =~ /class\s+(\w+::[\w:]+)/mgs ) {
            push @struct_classes, $1;
        }
    }

    my $typemap_start  = _typemap_start();
    my $typemap_input  = _typemap_input_start();
    my $typemap_output = _typemap_output_start();

    for my $struct_class (@struct_classes) {
        my ($ctype) = $struct_class =~ /([^:]+$)/;
        my $vtable = $PREFIX . uc($ctype);
        my $uc_ctype = $vtable . "_";
        $ctype         .= ' *';
        $typemap_start .= "$ctype\t$uc_ctype\n";
        $typemap_start .= $prefix . "$ctype\t$uc_ctype\n";
        $typemap_input .= <<END_INPUT;
$uc_ctype
    \$var = ($prefix$ctype)SV_TO_KOBJ(\$arg, &$vtable);

END_INPUT

        $typemap_output .= <<END_OUTPUT;
$uc_ctype
    \$arg = (SV*)Kino_Obj_To_Host(\$var);
    KINO_DECREF(\$var);

END_OUTPUT
    }

    # Blast it out.
    print "Writing typemap\n";
    unlink 'typemap';
    sysopen( my $typemap_fh, 'typemap', O_CREAT | O_WRONLY | O_EXCL )
        or die "Couldn't open 'typemap' for writing: $!";
    print $typemap_fh "$typemap_start $typemap_input $typemap_output"
        or die "Print to 'typemap' failed: $!";
    $self->add_to_cleanup('typemap');
}

my @int_types = qw( i8 u8 i16 u16 i32 u32 i64 u64);

sub _typemap_start {
    my $content = <<END_STUFF;
# Auto-generated file.

TYPEMAP
chy_bool_t\tCHY_BOOL
chy_i8_t\tCHY_SIGNED_INT
chy_i16_t\tCHY_SIGNED_INT
chy_i32_t\tCHY_SIGNED_INT
chy_i64_t\tCHY_BIG_INT
chy_u8_t\tCHY_UNSIGNED_INT
chy_u16_t\tCHY_UNSIGNED_INT
chy_u32_t\tCHY_UNSIGNED_INT
chy_u64_t\tCHY_BIG_INT

kino_ClassNameBuf \tCLASSNAMEBUF
${prefix}CharBuf\tCHARBUF_NOT_POINTER
END_STUFF

    return $content;
}

sub _typemap_input_start {
    return <<END_STUFF;
    
INPUT

CHY_BOOL
    \$var = (\$type)SvTRUE(\$arg);

CHY_SIGNED_INT 
    \$var = (\$type)SvIV(\$arg);

CHY_UNSIGNED_INT
    \$var = (\$type)SvUV(\$arg);

CHY_BIG_INT 
    \$var = (\$type)SvNV(\$arg);

CLASSNAMEBUF
    \$var = XSBind_sv_to_class_name(\$arg);

CHARBUF_NOT_POINTER
        \$var.ref.count = 1;
        \$var.vtable    = (${prefix}VTable*)&${PREFIX}ZOMBIECHARBUF;
        \$var.ptr       = SvPVutf8_nolen(\$arg);
        \$var.size      = SvCUR(\$arg);

END_STUFF
}

sub _typemap_output_start {
    return <<'END_STUFF';

OUTPUT

CHY_BOOL
    sv_setiv($arg, (IV)$var);

CHY_SIGNED_INT
    sv_setiv($arg, (IV)$var);

CHY_UNSIGNED_INT
    sv_setuv($arg, (UV)$var);

CHY_BIG_INT
    sv_setnv($arg, (NV)$var);

END_STUFF
}

=begin comment

We build our Perl release tarball from the $REPOS_ROOT/perl, rather than from
the top-level.

Because some items we need are outside this directory, we need to copy a
bunch of stuff, then update the MANIFEST so that the newly copied files get
included.

After the tarball is done, we delete the copied directories, then revert the
MANIFEST so that during ordinary development we don't get a bunch of errors
about missing files every time we run Build.PL.  

=end comment
=cut

sub ACTION_dist {
    my $self = shift;

    $self->dispatch('pod');
    my @dirs_to_copy = qw( core charmonizer devel boilerplater );

    print "Copying files...\n";
    for my $dir (@dirs_to_copy) {
        confess("'$dir' already exists") if -e $dir;
        system("cp -R ../$dir $dir");
    }

    print "Updating MANIFEST temporarily...\n";
    $self->dispatch('manifest');

    print "Generating no_index list...\n";
    my $no_index = $self->_gen_pause_exclusion_list;
    $self->meta_add( { no_index => $no_index } );

    $self->SUPER::ACTION_dist;

    # Clean up and restore MANIFEST.
    print "Removing copied files...\n";
    rmtree($_) for @dirs_to_copy;
    print "Restoring MANIFEST...\n";
    move( 'MANIFEST.bak', 'MANIFEST' );
}

# Generate a list of files for PAUSE, search.cpan.org, etc to ignore.
sub _gen_pause_exclusion_list {
    my $self = shift;

    # Only exclude files that are actually on-board.
    open( my $man_fh, '<', 'MANIFEST' ) or die "Can't open MANIFEST: $!";
    my @manifest_entries = <$man_fh>;
    chomp @manifest_entries;

    my @excluded_files;
    for my $entry (@manifest_entries) {
        # Allow README.
        next if $entry =~ m#^README#;

        # Allow public modules.
        if ( $entry =~ m#^lib.+\.(pm|pod)$# ) {
            open( my $fh, '<', $entry ) or die "Can't open '$entry': $!";
            my $content = do { local $/; <$fh> };
            next if $content =~ /=head1\s*NAME/;
        }

        # Disallow everything else.
        push @excluded_files, $entry;
    }

    # Exclude redacted modules.
    require 'lib/KinoSearch/Redacted.pm';
    my @redacted = map {
        my @parts = split( /\W+/, $_ );
        catfile( 'lib', @parts ) . '.pm'
    } KinoSearch::Redacted->redacted, KinoSearch::Redacted->hidden;
    push @excluded_files, @redacted;

    my %uniquifier;
    @excluded_files = sort grep { !$uniquifier{$_}++ } @excluded_files;
    return { file => \@excluded_files };
}

1;

__END__

=head1 COPYRIGHT

Copyright 2005-2009 Marvin Humphrey

=cut
