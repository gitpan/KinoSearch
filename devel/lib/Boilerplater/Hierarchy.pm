use strict;
use warnings;

package Boilerplater::Hierarchy;
use Carp;
use File::Find qw( find );
use File::Spec::Functions qw( catfile splitpath );
use File::Path qw( mkpath );

use Boilerplater::Util qw( slurp_file current );
use Boilerplater qw( $prefix $Prefix $PREFIX );
use Boilerplater::Class;
use Boilerplater::Class::Final;

sub new {
    my $ignore = shift;
    my $self = bless {
        base_dir => undef,    # the directory we begin reading files from
        dest_dir => undef,    # the directory we write files to
        tree     => {},       # the hierarchy, with Obj at its base
        @_,
        },
        __PACKAGE__;
    return $self;
}

# Slurp all .h files.  For those which contain one or more BOIL_CLASS
# directives, create a Boilerplater::Class object. (Discard the rest.)
# Finally, arrange the class objects into a tree with Obj at the root.
sub build {
    my $self = shift;
    my ( $base_dir, $dest_dir ) = @{$self}{qw( base_dir dest_dir )};

    # collect filenames
    my @all_h_paths;
    find(
        {   wanted => sub {
                if ( $File::Find::name =~ /\.h$/ ) {
                    push @all_h_paths, $File::Find::name;
                }
            },
            no_chdir => 1,
        },
        $self->{base_dir},
    );

    # process any file that has at least one class declaration
    my %classes;
    for my $h_path (@all_h_paths) {
        my ($r_path) = $h_path =~ /(.*)\.h/;
        $r_path .= '.r';
        $r_path =~ s/^$base_dir\W*//
            or die "'$h_path' doesn't start with '$base_dir'";
        $r_path = catfile( $dest_dir, $r_path );
        my ( undef, $dir, undef ) = splitpath($r_path);
        mkpath $dir unless -d $dir;

        my $content = slurp_file($h_path);
        while (
            $content =~ s/
            .*?
            ^(
                $PREFIX
                    (FINAL_)?
                CLASS
                .*?
                $PREFIX 
					END_CLASS\s*
            )
            //msx
            )
        {
            my $final       = defined $2;
            my $class_class = $final
                ? 'Boilerplater::Class::Final'
                : 'Boilerplater::Class';
            my $class = $class_class->new(
                content => $1,
                h_path  => $h_path,
                r_path  => $r_path,
            );
            $classes{ $class->get_class_name } = $class;
        }
    }

    # wrangle the classes into a hierarchy and figure out inheritance
    while ( my ( $nickname, $class ) = each %classes ) {
        my $parent_name = $class->get_parent_class_name;
        next if $parent_name eq '';    # skip Obj, which has no parent
        $classes{$parent_name}->add_child($class);
    }

    # make Obj the root
    my ($obj_class) = grep {m/\bObj$/} keys %classes;
    $self->{tree} = $classes{$obj_class};
    $self->{tree}->bequeath;
}

sub write_all_modified {
    my $self = shift;

    #rewrite all if this file has changed.
    my $modified = !current( $0, $self->{tree}->get_r_path );

    # seed the recursive write
    $self->_write_if_modified( $self->{tree}, $modified );
}

# recursive helper function
sub _write_if_modified {
    my ( $self, $class, $modified ) = @_;

    if ( !-e $class->get_r_path ) {
        $modified = 1;
        $self->_start_file($class);

    }

    # if any parent is modified, rewrite all the kids
    $modified = $class->write_if_modified($modified);

    # proceed to the next generation
    for my $kid ( $class->get_children ) {
        if ( $class->is_final ) {
            confess(  "Attempt to inherit from final class "
                    . $class->get_class_name . " by "
                    . $kid->get_class_name );
        }
        $self->_write_if_modified( $kid, $modified );
    }
}

sub _start_file {
    my ( $self, $class ) = @_;
    my $include_h_path = $class->get_h_path;
    $include_h_path =~ s/^$self->{base_dir}\W*//;
    my $r_path              = $class->get_r_path;
    my $guard_name          = $class->guard_name;
    my $include_guard_start = $class->guard_start;
    my $include_guard_close = $class->guard_close;
    open( my $fh, '>', $r_path ) or confess("Can't open '$r_path': $!");
    print $fh <<END_STUFF;
$self->{header}

$include_guard_start
#include "$include_h_path"

$include_guard_close

$self->{footer}
END_STUFF

}

1;
