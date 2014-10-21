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

BEGIN { unshift @PATH, curdir() }

sub project_name {'Lucy'}
sub project_nick {'Lucy'}

sub xs_filepath { shift->project_name . ".xs" }
sub autobind_pm_path {
    catfile( 'lib', shift->project_name, 'Autobinding.pm' );
}

sub extra_ccflags {
    my $self          = shift;
    my $debug_env_var = uc( $self->project_nick ) . "_DEBUG";

    my $extra_ccflags = "";
    if ( defined $ENV{$debug_env_var} ) {
        $extra_ccflags .= "-D$debug_env_var ";
        # Allow override when Perl was compiled with an older version.
        my $gcc_version = $ENV{REAL_GCC_VERSION} || $Config{gccversion};
        if ( defined $gcc_version ) {
            $gcc_version =~ /^(\d+(\.\d+)?)/ or die "no match";
            $gcc_version = $1;
            $extra_ccflags .= "-DPERL_GCC_PEDANTIC -ansi -pedantic -Wall "
                . "-std=c89 -Wno-long-long ";
            $extra_ccflags .= "-Wextra " if $gcc_version >= 3.4;    # correct
            $extra_ccflags .= "-Wno-variadic-macros "
                if $gcc_version > 3.4;    # at least not on gcc 3.4
        }
    }

    return $extra_ccflags;
}

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

sub new { shift->SUPER::new( recursive_test_files => 1, @_ ) }

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
    my $charmony_in   = 'charmony_in';
    my $charmony_path = 'charmony.h';

    $self->dispatch('charmonizer');

    return if $self->up_to_date( $CHARMONIZE_EXE_PATH, $charmony_path );
    print "\nWriting $charmony_path...\n\n";

    # Clean up after Charmonizer if it doesn't succeed on its own.
    $self->add_to_cleanup("_charm*");

    # Write the infile with which to communicate args to charmonize.
    my $os_name   = lc( $Config{osname} );
    my $flags     = "$Config{ccflags} " . $self->extra_ccflags;
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

    if ( $ENV{CHARM_VALGRIND} ) {
        system(
            "valgrind --leak-check=yes ./$CHARMONIZE_EXE_PATH $charmony_in")
            and die "Failed to write charmony.h";
    }
    else {
        system( $CHARMONIZE_EXE_PATH, $charmony_in )
            and die "Failed to write charmony.h";
    }
}

sub _compile_boilerplater {
    my $self = shift;

    require Boilerplater::Hierarchy;
    require Boilerplater::Binding::Perl;
    require Boilerplater::Binding::Perl::Class;

    # Compile Boilerplater.
    my $hierarchy = Boilerplater::Hierarchy->new(
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

    my $binding = Boilerplater::Binding::Perl->new(
        hierarchy   => $hierarchy,
        pm_path     => $self->autobind_pm_path,
        xs_path     => $self->xs_filepath,
        boot_class  => $self->project_name,
        boot_func   => lc( $self->project_nick ) . "_Boot_bootstrap",
        boot_h_file => lc( $self->project_nick ) . "_boot.h",
        boot_c_file => lc( $self->project_nick ) . "_boot.c",
        header      => $self->autogen_header,
        footer      => $self->copyfoot,
    );

    return ( $hierarchy, $binding, \@pm_filepaths_with_xs );
}

sub ACTION_pod { shift->_write_pod(@_) }

sub _write_pod {
    my ( $self, $binding ) = @_;
    if ( !$binding ) {
        ( undef, $binding ) = $self->_compile_boilerplater;
    }
    my $pod_files = $binding->prepare_pod( lib_dir => 'lib' );
    while ( my ( $filepath, $pod ) = each %$pod_files ) {
        $self->add_to_cleanup($filepath);
        unlink $filepath;
        print "Writing $filepath...\n";
        sysopen( my $pod_fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
            or confess("Can't open '$filepath': $!");
        print $pod_fh $pod;
    }
}

sub ACTION_boilerplater {
    my $self        = shift;
    my $xs_filepath = $self->xs_filepath;

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
        [ $xs_filepath,   $AUTOGEN_DIR, ]
        );

    # Write out all autogenerated files.
    my ( $hierarchy, $perl_binding, $pm_filepaths_with_xs )
        = $self->_compile_boilerplater;
    require Boilerplater::Binding::Core;
    my $core_binding = Boilerplater::Binding::Core->new(
        hierarchy => $hierarchy,
        dest      => $AUTOGEN_DIR,
        header    => $self->autogen_header,
        footer    => $self->copyfoot,
    );
    my $modified = $core_binding->write_all_modified;
    if ($modified) {
        $core_binding->write_boil_h;
        unlink('typemap');
        print "Writing typemap...\n";
        $self->add_to_cleanup('typemap');
        $perl_binding->write_xs_typemap;
    }

    # Rewrite XS if either any .bp files or relevant .pm files were modified.
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
            [ @$bp_filepaths, @$pm_filepaths_with_xs ], $xs_filepath
        )
        )
    {
        utime( time, time, $xs_filepath );    # touch
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
    my $self             = shift;
    my $suppfile         = lc( $self->project_nick ) . "perl.supp";
    my $valgrind_env_var = uc( $self->project_nick ) . "_VALGRIND";
    return
          "PERL_DESTRUCT_LEVEL=2 $valgrind_env_var=1 valgrind "
        . "--leak-check=yes "
        . "--show-reachable=yes "
        . "--num-callers=10 "
        . "--suppressions=../devel/conf/$suppfile ";
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
    my $self         = shift;
    my $project_name = $self->project_name;
    my $xs_filepath  = $self->xs_filepath;

    require ExtUtils::ParseXS;

    my $cbuilder = Lucy::Build::CBuilder->new;
    my $archdir = catdir( $self->blib, 'arch', 'auto', $project_name );
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
            extra_compiler_flags => $self->extra_ccflags,
            include_dirs         => \@include_dirs,
            object_file          => $o_file,
        );
    }

    # .xs => .c
    my $perl_binding_c_file = "$project_name.c";
    $self->add_to_cleanup($perl_binding_c_file);
    if ( !$self->up_to_date( $xs_filepath, $perl_binding_c_file ) ) {
        ExtUtils::ParseXS::process_file(
            filename   => $xs_filepath,
            prototypes => 0,
            output     => $perl_binding_c_file,
        );
    }

    # .c => .o
    my $version             = $self->dist_version;
    my $perl_binding_o_file = "$project_name$Config{_o}";
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
    my $bs_file = catfile( $archdir, "$project_name.bs" );
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
    my $lib_file = catfile( $archdir, "$project_name.$Config{dlext}" );
    if ( !$self->up_to_date( [ @objects, $AUTOGEN_DIR ], $lib_file ) ) {
        $cbuilder->link(
            module_name => $project_name,
            objects     => \@objects,
            lib_file    => $lib_file,
        );
    }
}

sub ACTION_code {
    my $self = shift;

    $self->dispatch('boilerplater');
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

sub ACTION_dist {
    my $self = shift;

    $self->dispatch('pod');

    # We build our Perl release tarball from $REPOS_ROOT/perl, rather than
    # from the top-level.
    #
    # Because some items we need are outside this directory, we need to copy a
    # bunch of stuff.  After the tarball is packaged up, we delete the copied
    # directories.
    my @dirs_to_copy = qw( core charmonizer devel boilerplater );
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
    my $project_name = $self->project_name;
    require "buildlib/$project_name/Redacted.pm";
    my $redacted_package = $project_name . "::Redacted";
    my @redacted         = map {
        my @parts = split( /\W+/, $_ );
        catfile( 'lib', @parts ) . '.pm'
    } $redacted_package->redacted, $redacted_package->hidden;
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
