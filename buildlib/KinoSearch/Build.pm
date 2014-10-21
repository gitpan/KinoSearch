use strict;
use warnings;

use lib '../clownfish/lib';
use lib 'clownfish/lib';

package KinoSearch::Build::CBuilder;
BEGIN { our @ISA = "ExtUtils::CBuilder"; }
use Config;

my %cc;

sub new {
    my ($class, %args) = @_;
    require ExtUtils::CBuilder;
    my $self = $class->SUPER::new(%args);
    $cc{"$self"} = $args{'config'}->{'cc'};
    return $self;
}

sub get_cc { $cc{"$_[0]"} }

sub DESTROY {
    my $self = shift;
    delete $cc{"$self"};
}

# This method isn't implemented by CBuilder for Windows, so we issue a basic
# link command that works on at least one system and hope for the best.
sub link_executable {
    my ( $self, %args ) = @_;
    if ( $self->get_cc eq 'cl' ) {
        my ( $objects, $exe_file ) = @args{qw( objects exe_file )};
        $self->do_system("link /out:$exe_file @$objects");
        return $exe_file;
    }
    else {
        return $self->SUPER::link_executable(%args);
    }
}

package KinoSearch::Build;
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

BEGIN { unshift @PATH, curdir() }

sub xs_filepath { catfile( 'lib', "KinoSearch.xs" ) }
sub autobind_pm_path { catfile( 'lib', 'KinoSearch', 'Autobinding.pm' ); }

sub extra_ccflags {
    my $self = shift;
    my $extra_ccflags = defined $ENV{CFLAGS} ? "$ENV{CFLAGS} " : "";
    my $gcc_version 
        = $ENV{REAL_GCC_VERSION}
        || $self->config('gccversion')
        || undef;
    if ( defined $gcc_version ) {
        $gcc_version =~ /^(\d+(\.\d+))/
            or die "Invalid GCC version: $gcc_version";
        $gcc_version = $1;
    }

    if ( defined $ENV{KINO_DEBUG} ) {
        if ( defined $gcc_version ) {
            $extra_ccflags .= "-DKINO_DEBUG ";
            $extra_ccflags .= "-DPERL_GCC_PEDANTIC -std=gnu99 -pedantic -Wall ";
            $extra_ccflags .= "-Wextra " if $gcc_version >= 3.4;    # correct
            $extra_ccflags .= "-Wno-variadic-macros "
                if $gcc_version > 3.4;    # at least not on gcc 3.4
        }
    }

    if ( $ENV{KINO_VALGRIND} and defined $gcc_version ) {
        $extra_ccflags .= "-fno-inline-functions ";
    }

    # Compile as C++ under MSVC.
    if ( $self->config('cc') eq 'cl' ) {
        $extra_ccflags .= '/TP ';
    }

    if ( defined $gcc_version ) {
        # Tell GCC explicitly to run with maximum options.
        if ( $extra_ccflags !~ m/-std=/ ) {
            $extra_ccflags .= "-std=gnu99 ";
        }
        if ( $extra_ccflags !~ m/-D_GNU_SOURCE/ ) {
            $extra_ccflags .= "-D_GNU_SOURCE ";
        }
    }

    return $extra_ccflags;
}

=for Rationale

When the distribution tarball for the Perl binding of KinoSearch is built, core/,
charmonizer/, and any other needed files/directories are copied into the
perl/ directory within the main KinoSearch directory.  Then the distro is built from
the contents of the perl/ directory, leaving out all the files in ruby/, etc.
However, during development, the files are accessed from their original
locations.

=cut

my $is_distro_not_devel = -e 'core';
my $base_dir = $is_distro_not_devel ? curdir() : updir();

my $CHARMONIZE_EXE_PATH  = 'charmonize' . $Config{_exe};
my $CHARMONIZER_ORIG_DIR = catdir( $base_dir, 'charmonizer' );
my $CHARMONIZER_SRC_DIR  = catdir( $CHARMONIZER_ORIG_DIR, 'src' );
my $CORE_SOURCE_DIR      = catdir( $base_dir, 'core' );
my $AUTOGEN_DIR          = 'autogen';
my $XS_SOURCE_DIR        = 'xs';

sub new { shift->SUPER::new( recursive_test_files => 1, @_ ) }

# Build the charmonize executable.
sub ACTION_charmonizer {
    my $self = shift;

    # Gather .c and .h Charmonizer files.
    my $charm_source_files
        = $self->rscan_dir( $CHARMONIZER_SRC_DIR, qr/Charmonizer.+\.[ch]$/ );
    my $charmonize_c = catfile( $CHARMONIZER_ORIG_DIR, 'charmonize.c' );
    my @all_source = ( $charmonize_c, @$charm_source_files );

    # Don't compile if we're up to date.
    return if $self->up_to_date( \@all_source, $CHARMONIZE_EXE_PATH );

    print "Building $CHARMONIZE_EXE_PATH...\n\n";

    my $cbuilder = KinoSearch::Build::CBuilder->new( 
        config => { cc => $self->config('cc') },
    );

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
            include_dirs         => [$CHARMONIZER_SRC_DIR],
            extra_compiler_flags => $self->extra_ccflags,
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
    my $charmony_path = 'charmony.h';

    $self->dispatch('charmonizer');

    return if $self->up_to_date( $CHARMONIZE_EXE_PATH, $charmony_path );
    print "\nWriting $charmony_path...\n\n";

    # Clean up after Charmonizer if it doesn't succeed on its own.
    $self->add_to_cleanup("_charm*");
    $self->add_to_cleanup($charmony_path);

    # Prepare arguments to charmonize.
    my $cc        = $self->config('cc'); 
    my $flags     = $self->config('ccflags') . ' ' . $self->extra_ccflags;
    my $verbosity = $ENV{DEBUG_CHARM} ? 2 : 1;
    $flags =~ s/"/\\"/g;

    if ( $ENV{CHARM_VALGRIND} ) {
        system(   "valgrind --leak-check=yes ./$CHARMONIZE_EXE_PATH $cc "
                . "\"$flags\" $verbosity" )
            and die "Failed to write charmony.h";
    }
    else {
        system("./$CHARMONIZE_EXE_PATH \"$cc\" \"$flags\" $verbosity")
            and die "Failed to write charmony.h: $!";
    }
}

sub _compile_clownfish {
    my $self = shift;

    require Clownfish::Hierarchy;
    require Clownfish::Binding::Perl;
    require Clownfish::Binding::Perl::Class;

    # Compile Clownfish.
    my $hierarchy = Clownfish::Hierarchy->new(
        source => $CORE_SOURCE_DIR,
        dest   => $AUTOGEN_DIR,
    );
    $hierarchy->build;

    # Process all __BINDING__ blocks.
    my $pm_filepaths = $self->rscan_dir( 'lib', qr/\.pm$/ );
    my @pm_filepaths_with_xs;
    for my $pm_filepath (@$pm_filepaths) {
        open( my $pm_fh, '<', $pm_filepath )
            or die "Can't open '$pm_filepath': $!";
        my $pm_content = do { local $/; <$pm_fh> };
        my ($autobind_frag)
            = $pm_content =~ /^__BINDING__\s*(.*?)(?:^__\w+__|\Z)/sm;
        if ($autobind_frag) {
            push @pm_filepaths_with_xs, $pm_filepath;
            eval $autobind_frag;
            confess("Invalid __BINDING__ from $pm_filepath: $@") if $@;
        }
    }

    my $binding = Clownfish::Binding::Perl->new(
        parcel     => 'KinoSearch',
        hierarchy  => $hierarchy,
        lib_dir    => 'lib',
        boot_class => 'KinoSearch',
        header     => $self->autogen_header,
        footer     => $self->copyfoot,
    );

    return ( $hierarchy, $binding, \@pm_filepaths_with_xs );
}

sub ACTION_pod { shift->_write_pod(@_) }

sub _write_pod {
    my ( $self, $binding ) = @_;
    if ( !$binding ) {
        ( undef, $binding ) = $self->_compile_clownfish;
    }
    my $pod_files = $binding->prepare_pod( lib_dir => 'lib' );
    print "Writing POD...\n";
    while ( my ( $filepath, $pod ) = each %$pod_files ) {
        $self->add_to_cleanup($filepath);
        unlink $filepath;
        sysopen( my $pod_fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
            or confess("Can't open '$filepath': $!");
        print $pod_fh $pod;
    }
}

sub ACTION_clownfish {
    my $self        = shift;
    my $xs_filepath = $self->xs_filepath;

    $self->dispatch('charmony');

    # Create destination dir, copy xs helper files.
    if ( !-d $AUTOGEN_DIR ) {
        mkdir $AUTOGEN_DIR or die "Can't mkdir '$AUTOGEN_DIR': $!";
    }
    $self->add_to_cleanup($AUTOGEN_DIR);

    my $pm_filepaths  = $self->rscan_dir( 'lib',            qr/\.pm$/ );
    my $cfh_filepaths = $self->rscan_dir( $CORE_SOURCE_DIR, qr/\.cfh$/ );

    # Don't bother parsing Clownfish files if everything's up to date.
    return
        if $self->up_to_date(
        [ @$cfh_filepaths, @$pm_filepaths ],
        [ $xs_filepath,    $AUTOGEN_DIR, ]
        );

    # Write out all autogenerated files.
    print "Parsing Clownfish files...\n";
    my ( $hierarchy, $perl_binding, $pm_filepaths_with_xs )
        = $self->_compile_clownfish;
    require Clownfish::Binding::Core;
    my $core_binding = Clownfish::Binding::Core->new(
        hierarchy => $hierarchy,
        dest      => $AUTOGEN_DIR,
        header    => $self->autogen_header,
        footer    => $self->copyfoot,
    );
    print "Writing Clownfish autogenerated files...\n";
    my $modified = $core_binding->write_all_modified;
    if ($modified) {
        unlink('typemap');
        print "Writing typemap...\n";
        $self->add_to_cleanup('typemap');
        $perl_binding->write_xs_typemap;
    }

    # Rewrite XS if either any .cfh files or relevant .pm files were modified.
    $modified ||=
        $self->up_to_date( \@$pm_filepaths_with_xs, $xs_filepath )
        ? 0
        : 1;

    if ($modified) {
        $self->add_to_cleanup($xs_filepath);
        $self->add_to_cleanup( $self->autobind_pm_path );
        $perl_binding->write_boot;
        $perl_binding->write_bindings;
        $self->_write_pod($perl_binding);
    }

    # Touch autogenerated files in case the modifications were inconsequential
    # and didn't trigger a rewrite, so that we won't have to check them again
    # next pass.
    if (!$self->up_to_date(
            [ @$cfh_filepaths, @$pm_filepaths_with_xs ], $xs_filepath
        )
        )
    {
        utime( time, time, $xs_filepath );    # touch
    }
    if (!$self->up_to_date(
            [ @$cfh_filepaths, @$pm_filepaths_with_xs ], $AUTOGEN_DIR
        )
        )
    {
        utime( time, time, $AUTOGEN_DIR );    # touch
    }
}

# Write ppport.h, which supplies some XS routines not found in older Perls and
# allows us to use more up-to-date XS API while still supporting Perls back to
# 5.8.3.
#
# The Devel::PPPort docs recommend that we distribute ppport.h rather than
# require Devel::PPPort itself, but ppport.h isn't compatible with the Apache
# license.
sub ACTION_ppport {
    my $self = shift;
    if ( !-e 'ppport.h' ) {
        require Devel::PPPort;
        $self->add_to_cleanup('ppport.h');
        Devel::PPPort::WriteFile();
    }
}

sub ACTION_suppressions {
    my $self       = shift;
    my $LOCAL_SUPP = 'local.supp';
    return
        if $self->up_to_date( '../devel/bin/valgrind_triggers.pl',
        $LOCAL_SUPP );

    # Generate suppressions.
    print "Writing $LOCAL_SUPP...\n";
    $self->add_to_cleanup($LOCAL_SUPP);
    my $command
        = "yes | "
        . $self->_valgrind_base_command
        . "--gen-suppressions=yes "
        . $self->perl
        . " ../devel/bin/valgrind_triggers.pl 2>&1";
    my $suppressions = `$command`;
    $suppressions =~ s/^==.*?\n//mg;
    my $rule_number = 1;
    while ( $suppressions =~ /<insert a.*?>/ ) {
        $suppressions =~ s/^\s*<insert a.*?>/{\n  <core_perl_$rule_number>/m;
        $rule_number++;
    }

    # Change e.g. fun:_vgrZU_libcZdsoZa_calloc to fun:calloc
    $suppressions =~ s/fun:\w+_((m|c|re)alloc)/fun:$1/g;

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
        unless $self->config('ccflags') =~ /-D?DEBUGGING\b/;
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
    my $self        = shift;
    my $xs_filepath = $self->xs_filepath;

    $self->dispatch('ppport');

    require ExtUtils::ParseXS;

    my $cbuilder = KinoSearch::Build::CBuilder->new(
        config => { cc => $self->config('cc') },
    );
    my $archdir = catdir( $self->blib, 'arch', 'auto', 'KinoSearch', );
    mkpath( $archdir, 0, 0777 ) unless -d $archdir;
    my @include_dirs = (
        curdir(), $CORE_SOURCE_DIR, $AUTOGEN_DIR, $XS_SOURCE_DIR,
        $CHARMONIZER_SRC_DIR,
    );
    my @objects;

    # Compile C source files.
    my $c_files = $self->rscan_dir( $CORE_SOURCE_DIR, qr/\.c$/ );
    push @$c_files, @{ $self->rscan_dir( $XS_SOURCE_DIR,       qr/\.c$/ ) };
    push @$c_files, @{ $self->rscan_dir( $CHARMONIZER_SRC_DIR, qr/\.c$/ ) };
    push @$c_files, @{ $self->rscan_dir( $AUTOGEN_DIR,         qr/\.c$/ ) };
    for my $c_file (@$c_files) {
        my $o_file = $c_file;
        $o_file =~ s/\.c/$Config{_o}/;
        push @objects, $o_file;
        next if $self->up_to_date( $c_file, $o_file );
        $self->add_to_cleanup($o_file);
        $cbuilder->compile(
            source               => $c_file,
            extra_compiler_flags => $self->extra_ccflags,
            include_dirs         => \@include_dirs,
            object_file          => $o_file,
        );
    }

    # .xs => .c
    my $perl_binding_c_file = "lib/KinoSearch.c";
    $self->add_to_cleanup($perl_binding_c_file);
    if ( !$self->up_to_date( $xs_filepath, $perl_binding_c_file ) ) {
        ExtUtils::ParseXS::process_file(
            filename   => $xs_filepath,
            prototypes => 0,
            output     => $perl_binding_c_file,
        );
    }

    # .c => .o
    my $version = $self->dist_version;
    my $perl_binding_o_file = catfile( 'lib', "KinoSearch$Config{_o}" );
    unshift @objects, $perl_binding_o_file;
    $self->add_to_cleanup($perl_binding_o_file);
    if ( !$self->up_to_date( $perl_binding_c_file, $perl_binding_o_file ) ) {
        $cbuilder->compile(
            source               => $perl_binding_c_file,
            extra_compiler_flags => $self->extra_ccflags,
            include_dirs         => \@include_dirs,
            object_file          => $perl_binding_o_file,
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
    my $bs_file = catfile( $archdir, "KinoSearch.bs" );
    $self->add_to_cleanup($bs_file);
    if ( !$self->up_to_date( $perl_binding_o_file, $bs_file ) ) {
        require ExtUtils::Mkbootstrap;
        ExtUtils::Mkbootstrap::Mkbootstrap($bs_file);
        if ( !-f $bs_file ) {
            # Create file in case Mkbootstrap didn't do anything.
            open( my $fh, '>', $bs_file )
                or confess "Can't open $bs_file: $!";
        }
        utime( (time) x 2, $bs_file );    # touch
    }

    # .o => .(a|bundle)
    my $lib_file = catfile( $archdir, "KinoSearch.$Config{dlext}" );
    if ( !$self->up_to_date( [ @objects, $AUTOGEN_DIR ], $lib_file ) ) {
        $cbuilder->link(
            module_name => 'KinoSearch',
            objects     => \@objects,
            lib_file    => $lib_file,
        );
    }
}

sub ACTION_code {
    my $self = shift;

    $self->dispatch('clownfish');
    $self->dispatch('compile_custom_xs');

    $self->SUPER::ACTION_code;
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
    return <<END_COPYFOOT;
/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
END_COPYFOOT
}

sub ACTION_dist {
    my $self = shift;

    $self->dispatch('pod');

    # We build our Perl release tarball from $REPOS_ROOT/perl, rather than
    # from the top-level.
    #
    # Because some items we need are outside this directory, we need to copy a
    # bunch of stuff.  After the tarball is packaged up, we delete the copied
    # directories.
    my @dirs_to_copy = qw( core charmonizer devel clownfish );
    print "Copying files...\n";
    for my $dir (@dirs_to_copy) {
        confess("'$dir' already exists") if -e $dir;
        system("cp -R ../$dir $dir");
    }

    $self->dispatch('manifest');
    my $no_index = $self->_gen_pause_exclusion_list;
    $self->meta_add( { no_index => $no_index } );
    $self->SUPER::ACTION_dist;

    # Clean up.
    print "Removing copied files...\n";
    rmtree($_) for @dirs_to_copy;
    unlink($_) for qw( MANIFEST META.yml );
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
    if ( eval { require "buildlib/KinoSearch/Redacted.pm" } ) {
        my @redacted = map {
            my @parts = split( /\W+/, $_ );
            catfile( 'lib', @parts ) . '.pm'
        } KinoSearch::Redacted->redacted, KinoSearch::Redacted->hidden;
        push @excluded_files, @redacted;
    }

    my %uniquifier;
    @excluded_files = sort grep { !$uniquifier{$_}++ } @excluded_files;
    return { file => \@excluded_files };
}

1;

__END__

__COPYRIGHT__

Copyright 2005-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

