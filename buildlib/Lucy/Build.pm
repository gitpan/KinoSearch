use strict;
use warnings;

package Lucy::Build;
use base qw( Module::Build );

# Don't crash Build.PL if CBuilder isn't installed yet
BEGIN { eval "use ExtUtils::CBuilder;"; }

use File::Spec::Functions
    qw( catdir catfile curdir splitpath updir no_upwards );
use File::Path qw( mkpath rmtree );
use File::Copy qw( copy move );
use File::Find qw( find );
use Config;
use Env qw( @PATH );

unshift @PATH, curdir();

=for Rationale

When the distribution tarball for the Perl binding of Lucy is built, c_src/,
c_test/, and any other needed files/directories are copied into the perl/
directory within the main Lucy directory.  Then the distro is built from the
contents of the perl/ directory, leaving out all the files in ruby/, etc.
However, during development, the files are accessed from their original
locations.

=cut

my $is_distro_not_devel = -e 'charmonizer';
my $base_dir = $is_distro_not_devel ? curdir() : updir();

my $METAQUOTE_EXE_PATH     = 'metaquote' . $Config{_exe};
my $CHARMONIZE_EXE_PATH    = 'charmonize' . $Config{_exe};
my $CHARMONIZER_SOURCE_DIR = catdir( $base_dir, 'charmonizer', 'src' );
my $FILTERED_DIR = catdir( $base_dir, qw( charmonizer filtered_src ) );
my $C_SOURCE_DIR = catdir( $base_dir, 'c_src' );
my $R_SOURCE_DIR = catdir( $C_SOURCE_DIR, 'r' );

my $EXTRA_CCFLAGS = '';
if ( $ENV{LUCY_DEBUG} || $ENV{KINO_DEBUG} ) {
    require version;
    if ( defined $Config{gccversion} ) {
        $Config{gccversion} =~ /^([\d\.]+)/ or die "no match";
        my $gcc_version = version->new("$1")->numify;
        $EXTRA_CCFLAGS = "-DPERL_GCC_PEDANTIC -ansi -pedantic -Wall "
            . "-std=c89 -Wno-long-long ";
        $EXTRA_CCFLAGS .= "-Wextra " if $gcc_version >= 3.4;    # correct
        $EXTRA_CCFLAGS .= "-Wno-variadic-macros "
            if $gcc_version > 3.2;    # at least not on gcc 3.2
    }
}
my $VALGRIND = $ENV{CHARM_VALGRIND} ? "valgrind --leak-check=full " : "";

=begin comment

Lucy::Build serves double duty as a build tool for both Lucy and KinoSearch,
in order to facilitate synchronization.

Since they will never be built at the same time, and since Module::Build pulls
some hocus pocus when creating objects that is difficult to control, we set a
few class variables rather than use instance variables to adapt the behavior
to one or the other.  

=end comment
=cut

my $XS_FILEPATH = catfile( 'lib', 'Lucy.xs' );
my ( $PREFIX, $Prefix, $prefix ) = qw( LUCY_ Lucy_ lucy_ );
my $kino_or_lucy = 'lucy';

sub use_kinosearch_mode {
    $XS_FILEPATH = catfile( 'lib', 'KinoSearch.xs' );
    ( $PREFIX, $Prefix, $prefix ) = qw( KINO_ Kino_ kino_ );
    $kino_or_lucy = 'kino';
}

# Compile the metaquote source filter utility.
sub ACTION_metaquote {
    my $self = shift;
    my $source_path
        = catfile( $base_dir, qw( charmonizer metaquote_src metaquote.c ) );

    # don't compile if we're up to date
    return if $self->up_to_date( [$source_path], $METAQUOTE_EXE_PATH );

    # compile
    print "\nBuilding $METAQUOTE_EXE_PATH...\n\n";
    my $cbuilder = ExtUtils::CBuilder->new;
    my $o_file   = $cbuilder->compile(
        source               => $source_path,
        extra_compiler_flags => $EXTRA_CCFLAGS,
    );
    $cbuilder->link_executable(
        objects  => [$o_file],
        exe_file => $METAQUOTE_EXE_PATH,
    );

    # clean both the object file and the executable
    $self->add_to_cleanup( $o_file, $METAQUOTE_EXE_PATH );
}

# Build the charmonize executable.
sub ACTION_charmonizer {
    my $self = shift;

    $self->dispatch('metaquote');

    # gather .charm and .harm files and run them through metaquote
    if ( !-d $FILTERED_DIR ) {
        mkpath($FILTERED_DIR) or die "can't mkpath '$FILTERED_DIR': $!";
    }
    my $charm_source_files = $self->_find_files( $CHARMONIZER_SOURCE_DIR,
        sub { $File::Find::name =~ /\.c?harm$/ } );
    my $filtered_files = $self->_metaquote_charm_files($charm_source_files);
    my $charmonize_c   = catfile( $base_dir, qw( charmonizer charmonize.c ) );
    my @all_source     = ( $charmonize_c, @$filtered_files );

    # don't compile if we're up to date
    return if $self->up_to_date( \@all_source, $CHARMONIZE_EXE_PATH );

    print "Building $CHARMONIZE_EXE_PATH...\n\n";

    my $cbuilder = ExtUtils::CBuilder->new;

    my @o_files;
    for (@all_source) {
        next unless /\.c$/;
        next if m#Charmonizer/Test#;
        my $o_file = $cbuilder->object_file($_);
        push @o_files, $o_file;

        next if $self->up_to_date( $_, $o_file );

        $cbuilder->compile(
            source               => $_,
            include_dirs         => [$FILTERED_DIR],
            extra_compiler_flags => $EXTRA_CCFLAGS,
        );
    }

    my $exe_path = $cbuilder->link_executable(
        objects  => \@o_files,
        exe_file => $CHARMONIZE_EXE_PATH,
    );

    $self->add_to_cleanup( $FILTERED_DIR, @$filtered_files, @o_files,
        $CHARMONIZE_EXE_PATH, );
}

sub _find_files {
    my ( $self, $dir, $test_sub ) = @_;
    my @files;
    find(
        {   wanted => sub {
                if ( $test_sub->() and $File::Find::name !~ /\.\.?$/ ) {
                    push @files, $File::Find::name;
                }
            },
            no_chdir => 1,
        },
        $dir,
    );
    return \@files;
}

sub _metaquote_charm_files {
    my ( $self, $charm_files ) = @_;
    my @filtered_files;

    for my $source_path (@$charm_files) {
        my $dest_path = $source_path;
        $dest_path =~ s#(.*)src#$1filtered_src#;
        $dest_path =~ s#\.charm#.c#;
        $dest_path =~ s#\.harm#.h#;

        push @filtered_files, $dest_path;

        next if ( $self->up_to_date( $source_path, $dest_path ) );

        # create directories if need be
        my ( undef, $dir, undef ) = splitpath($dest_path);
        if ( !-d $dir ) {
            $self->add_to_cleanup($dir);
            mkpath $dir or die "Couldn't mkpath $dir";
        }

        # run the metaquote filter
        system( $METAQUOTE_EXE_PATH, $source_path, $dest_path );
    }

    return \@filtered_files;
}

# Run the charmonizer executable, creating the charmony.h file.
sub ACTION_charmony {
    my $self          = shift;
    my $charmony_in   = 'charmony_in';
    my $charmony_path = 'charmony.h';

    $self->dispatch('charmonizer');

    return if $self->up_to_date( $CHARMONIZE_EXE_PATH, $charmony_path );
    print "\nWriting $charmony_path...\n\n";

    # write the infile with which to communicate args to charmonize
    my $os_name   = lc( $Config{osname} );
    my $flags     = "$Config{ccflags} $EXTRA_CCFLAGS";
    my $verbosity = $ENV{DEBUG_CHARM} ? 2 : 1;
    my $cc        = "$Config{cc}";
    open( my $infile_fh, '>', $charmony_in )
        or die "Can't open '$charmony_in': $!";
    print $infile_fh qq|
        <charm_os_name>$os_name</charm_os_name>
        <charm_cc_command>$cc</charm_cc_command>
        <charm_cc_flags>$flags</charm_cc_flags>
        <charm_verbosity>$verbosity</charm_verbosity>
    |;
    close $infile_fh or die "Can't close '$charmony_in': $!";

    if ($VALGRIND) {
        system("$VALGRIND ./$CHARMONIZE_EXE_PATH $charmony_in");
    }
    else {
        system( $CHARMONIZE_EXE_PATH, $charmony_in );
    }

    $self->add_to_cleanup( $charmony_path, $charmony_in );
}

sub ACTION_build_charm_test {
    my $self = shift;

    $self->dispatch('charmony');

    # collect source files
    my $source_path     = catfile( $base_dir, 'charmonizer', 'charm_test.c' );
    my $exe_path        = "charm_test$Config{_exe}";
    my $test_source_dir = catdir( $FILTERED_DIR, qw( Charmonizer Test ) );
    my $source_files    = $self->_find_files( $FILTERED_DIR,
        sub { $File::Find::name =~ m#Charmonizer/Test.*?\.c$# } );
    push @$source_files, $source_path;

    # collect include dirs
    my @include_dirs = ( $FILTERED_DIR, curdir() );

    # add Windows supplements
    if ( $Config{osname} =~ /mswin/i ) {
        my $win_compat_dir = catdir( $base_dir, 'c_src', 'compat' );
        push @include_dirs, $win_compat_dir;
        my $win_compat_files = $self->_find_files( $win_compat_dir,
            sub { $File::Find::name =~ m#\.c$# } );
        push @$source_files, @$win_compat_files;
    }

    return if $self->up_to_date( $source_files, $exe_path );

    my $cbuilder = ExtUtils::CBuilder->new;

    # compile and link "charm_test"
    my @o_files;
    for (@$source_files) {
        my $o_file = $cbuilder->compile(
            source               => $_,
            extra_compiler_flags => $EXTRA_CCFLAGS,
            include_dirs         => \@include_dirs,
        );
        push @o_files, $o_file;
    }
    $cbuilder->link_executable(
        objects  => \@o_files,
        exe_file => $exe_path,
    );

    $self->add_to_cleanup( @o_files, $exe_path );
}

sub ACTION_dynamic_xs {
    my $self    = shift;
    my $xs_code = "";

    $self->dispatch('boilerplater');
    $self->dispatch('build_charm_test');

    # create target directory within dir spec'd as c_source to M::B.
    my $xs_dir = catdir( $C_SOURCE_DIR, "xs" );
    if ( !-d $xs_dir ) {
        mkdir $xs_dir or die "Can't mkdir '$xs_dir': $!";
    }
    $self->add_to_cleanup($xs_dir);

    # copy XSHelper.h/c since M::B can't handle multiple c_source dirs
    my $helper_h_source = catfile( 'xshelper', "XSHelper.h" );
    my $helper_c_source = catfile( 'xshelper', "XSHelper.c" );
    my $helper_h_targ   = catfile( $xs_dir,    "XSHelper.h" );
    my $helper_c_targ   = catfile( $xs_dir,    "XSHelper.c" );
    $self->add_to_cleanup( $helper_h_targ, $helper_c_targ );
    if (!$self->up_to_date(
            [ $helper_h_source, $helper_c_source ],
            [ $helper_h_targ,   $helper_c_targ ]
        )
        )
    {
        copy( $helper_h_source, $helper_h_targ ) or die "Copy failed: $!";
        copy( $helper_c_source, $helper_c_targ ) or die "Copy failed: $!";
    }

    # build up a list of pound-include directives for all .h and .r files
    my $h_files = $self->_find_files( $C_SOURCE_DIR,
        sub { $File::Find::name =~ /\.h$/ } );
    my $r_files = $self->_find_files( $R_SOURCE_DIR,
        sub { $File::Find::name =~ /\.r$/ } );

    my $hr_includes = "";
    for ( @$h_files, @$r_files ) {
        s/.*src.(r.)?//;
        next if /ppport\.h/;
        $hr_includes .= qq|#include "$_"\n|;
    }

    # concatenate all XS frags
    my $pm_filepaths
        = $self->_find_files( 'lib', sub { $File::Find::name =~ /\.pm$/ } );
    my @pm_filepaths_with_xs;
    for my $pm_filepath (@$pm_filepaths) {
        open( my $pm_fh, '<', $pm_filepath )
            or die "Can't open '$pm_filepath': $!";
        my $pm_content = do { local $/; <$pm_fh> };
        my ($xs_frag) = $pm_content =~ /^__XS__\s*(.*?)^__\w+__/sm;
        next unless $xs_frag;
        $xs_code .= $xs_frag;
        push @pm_filepaths_with_xs, $pm_filepath;
    }

    # if nothing's been added to any file with XS, don't rewrite.
    return if $self->up_to_date( \@pm_filepaths_with_xs, $XS_FILEPATH );

    # prepend pound-includes and blast out the file
    $xs_code = qq|#include "xs/XSHelper.h"\n\n$hr_includes\n\n$xs_code|;
    $self->_write_autogenerated_file( $XS_FILEPATH, "[many files]",
        $xs_code );
}

sub ACTION_boilerplater {
    my $self = shift;

    # we only run boilerplater.pl during development
    if ($is_distro_not_devel) {
        print "Skipping boilerplater.pl...\n";
        return;
    }
    else {
        my $bp_path = catfile( $base_dir, 'devel', 'boilerplater.pl' );
        my $retval = system( 'perl', $bp_path, "--in=$C_SOURCE_DIR",
            "--out=$R_SOURCE_DIR", "--$kino_or_lucy" );
        $self->add_to_cleanup($R_SOURCE_DIR);
        exit($retval) if $retval;
    }
}

sub ACTION_code {
    my $self = shift;

    $self->include_dirs( [ curdir(), $R_SOURCE_DIR ] );
    $self->extra_compiler_flags( split / /, $EXTRA_CCFLAGS );
    $self->c_source($C_SOURCE_DIR);
    $self->dispatch('dynamic_xs');
    $self->dispatch('write_typemap');

    $self->SUPER::ACTION_code;
}

# Prepend a big fat warning to some content, then blast it out to a file.
sub _write_autogenerated_file {
    my ( $self, $outfilepath, $source_path, $content ) = @_;

    # assume that if it's autogenerated we'll want to clean it up later
    $self->add_to_cleanup($outfilepath);

    my $autogen_header = <<"END_AUTOGEN";
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 This file was auto-generated by Build.PL from
 $source_path

 ***********************************************/

END_AUTOGEN

    print "Writing $outfilepath\n";
    open( my $fh, '>', $outfilepath )
        or die "Couldn't open file '$outfilepath' for writing: $!";
    print $fh "$autogen_header\n$content"
        or die "Print to '$outfilepath' failed: $!";

    close $fh or die "Couldn't close file '$outfilepath': $!";
}

=for Rationale

All of our C-struct types share the same typemap profile, but can't be mapped
to a single type.  Instead of tediously hand-editing the typemap file, we
autogenerate the file. 

=cut

# write the typemap file.
sub ACTION_write_typemap {
    my $self = shift;

    my $pm_filepaths
        = $self->_find_files( 'lib', sub { $File::Find::name =~ /\.pm$/ } );
    return
        if ( -e 'typemap' and $self->up_to_date( $pm_filepaths, 'typemap' ) );

    # build up a list of C-struct classes
    my $h_filepaths = $self->_find_files(
        $C_SOURCE_DIR,
        sub {
            $File::Find::name =~ /\.h$/;
        }
    );
    my @struct_classes;
    for my $h_path (@$h_filepaths) {
        open( my $h_fh, '<', $h_path ) or die "Can't open '$h_path': $!";
        my $content = do { local $/; <$h_fh> };
        # minor violation of encapsulation, but will fail catastrophically
        while ( $content =~ /^$PREFIX(?:FINAL_)?CLASS\(\s*"([^"]+)"/mgs ) {
            push @struct_classes, $1;
        }
    }

    my $typemap_start  = _typemap_start();
    my $typemap_input  = _typemap_input_start();
    my $typemap_output = _typemap_output_start();

    for my $struct_class (@struct_classes) {
        my ($ctype) = $struct_class =~ /([^:]+$)/;
        my $uc_ctype = $PREFIX . uc($ctype) . "_";
        $ctype         .= ' *';
        $typemap_start .= "$ctype\t$uc_ctype\n";
        $typemap_start .= $prefix . "$ctype\t$uc_ctype\n";
        $typemap_input .= <<END_INPUT;
$uc_ctype
    if (sv_derived_from(\$arg, \\"$struct_class\\")) {
         \$var = INT2PTR(\$type,( SvIV((SV*)SvRV(\$arg)) ) );
    }
    else
        Perl_croak(aTHX_ \\"\$var is not of type $struct_class\\");

END_INPUT

        $typemap_output .= <<END_OUTPUT;
$uc_ctype
    sv_setref_pv(\$arg, \$var->_->class_name, (void*)\$var);

END_OUTPUT
    }

    # blast it out
    print "Writing typemap\n";
    open( my $typemap_fh, '>', 'typemap' )
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

const classname_char *\tCHY_CLASSNAME
${prefix}ByteBuf\tBYTEBUF_NOT_POINTER
${prefix}ByteBuf_utf8\tBYTEBUF_NOT_POINTER_UTF8
${prefix}ViewByteBuf\tVIEWBB_NOT_POINTER
${prefix}ViewByteBuf_utf8\tVIEWBB_NOT_POINTER_UTF8
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

CHY_CLASSNAME
    \$var = derive_class(\$arg);

BYTEBUF_NOT_POINTER
        \$var._ = &${PREFIX}BYTEBUF;
        \$var.ptr = SvPV_nolen(\$arg);
        \$var.len = SvCUR(\$arg);

BYTEBUF_NOT_POINTER_UTF8
        \$var._ = &${PREFIX}BYTEBUF;
        \$var.ptr = SvPVutf8_nolen(\$arg);
        \$var.len = SvCUR(\$arg);

VIEWBB_NOT_POINTER
        \$var._ = &${PREFIX}VIEWBYTEBUF;
        \$var.ptr = SvPV_nolen(\$arg);
        \$var.len = SvCUR(\$arg);

VIEWBB_NOT_POINTER
        \$var._ = &${PREFIX}VIEWBYTEBUF;
        \$var.ptr = SvPVutf8_nolen(\$arg);
        \$var.len = SvCUR(\$arg);

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

    $self->dispatch('boilerplater');
    print "Copying files...\n";
    for my $dir (qw( charmonizer c_src devel )) {
        die "'$dir' already exists" if -e $dir;
        system("cp -R ../$dir $dir");
    }

    print "Updating MANIFEST temporarily...\n";
    $self->dispatch('manifest');

    print "Generating no_index list...\n";
    my $no_index = $self->_gen_pause_exclusion_list;
    $self->meta_add( { no_index => $no_index } );

    $self->SUPER::ACTION_dist;

    # clean up and restore MANIFEST
    print "Removing copied files...\n";
    rmtree('charmonizer');
    rmtree('c_src');
    rmtree('devel');
    print "Restoring MANIFEST...\n";
    move( 'MANIFEST.bak', 'MANIFEST' );
}

# Generate a list of files for PAUSE, search.cpan.org, etc to ignore.
sub _gen_pause_exclusion_list {
    my $self = shift;

    # only exclude files that are actually on-board
    open( my $man_fh, '<', 'MANIFEST' ) or die "Can't open MANIFEST: $!";
    my @manifest_entries = <$man_fh>;
    chomp @manifest_entries;

    my @excluded_files;
    for my $entry ( sort @manifest_entries ) {
        # allow README
        next if $entry =~ m#^README#;

        # allow public modules
        if ( $entry =~ m#^lib.+\.(pm|pod)$# ) {
            open( my $fh, '<', $entry ) or die "Can't open '$entry': $!";
            my $content = do { local $/; <$fh> };
            next if $content =~ /=head1\s*NAME/;
        }

        # disallow everything else
        push @excluded_files, $entry;
    }

    return { file => \@excluded_files };
}

1;

__END__

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=cut
