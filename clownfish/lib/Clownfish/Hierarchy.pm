use strict;
use warnings;

package Clownfish::Hierarchy;
use Carp;
use File::Find qw( find );
use File::Spec::Functions qw( catfile splitpath );
use File::Path qw( mkpath );
use Fcntl;

use Clownfish::Util qw( slurp_file current verify_args );
use Clownfish::Class;
use Clownfish::Parser;

our %new_PARAMS = (
    source => undef,
    dest   => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless {
        parser => Clownfish::Parser->new,
        trees  => {},
        files  => {},
        %new_PARAMS,
        @_,
        },
        ref($either) || $either;
    for (qw( source dest)) {
        confess("Missing required param '$_'") unless $self->{$_};
    }
    return $self;
}

# Accessors.
sub get_source { shift->{source} }
sub get_dest   { shift->{dest} }

# Return flattened hierarchies.
sub ordered_classes {
    my $self = shift;
    my @all;
    for my $tree ( values %{ $self->{trees} } ) {
        push @all, $tree->tree_to_ladder;
    }
    return @all;
}

sub files { values %{ shift->{files} } }

# Slurp all Clownfish header files.
# Arrange the class objects into inheritance trees.
sub build {
    my $self = shift;
    $self->_parse_cf_files;
    $_->grow_tree for values %{ $self->{trees} };
}

sub _parse_cf_files {
    my $self   = shift;
    my $source = $self->{source};

    # Collect filenames.
    my @all_source_paths;
    find(
        {   wanted => sub {
                if ( $File::Find::name =~ /\.cfh$/ ) {
                    push @all_source_paths, $File::Find::name
                        unless /#/;    # skip emacs .#filename.h lock files
                }
            },
            no_chdir => 1,
            follow   => 1,    # follow symlinks if possible (noop on Windows)
        },
        $source,
    );

    # Process any file that has at least one class declaration.
    my %classes;
    for my $source_path (@all_source_paths) {
        # Derive the name of the class that owns the module file.
        my $source_class = $source_path;
        $source_class =~ s/\.cfh$//;
        $source_class =~ s/^\Q$source\E\W*//
            or die "'$source_path' doesn't start with '$source'";
        $source_class =~ s/\W/::/g;

        # Slurp, parse, add parsed file to pool.
        my $content = slurp_file($source_path);
        $content = $self->{parser}->strip_plain_comments($content);
        my $file = $self->{parser}
            ->file( $content, 0, source_class => $source_class, );
        confess("parse error for $source_path") unless defined $file;
        $self->{files}{$source_class} = $file;
        for my $class ( $file->classes ) {
            my $class_name = $class->get_class_name;
            confess "$class_name already defined"
                if exists $classes{$class_name};
            $classes{$class_name} = $class;
        }
    }

    # Wrangle the classes into hierarchies and figure out inheritance.
    while ( my ( $class_name, $class ) = each %classes ) {
        my $parent_name = $class->get_parent_class_name;
        if ( defined $parent_name ) {
            if ( not exists $classes{$parent_name} ) {
                confess(  "parent class '$parent_name' not defined "
                        . "for class '$class_name'" );
            }
            $classes{$parent_name}->add_child($class);
        }
        else {
            $self->{trees}{$class_name} = $class;
        }
    }
}

sub propagate_modified {
    my ( $self, $modified ) = @_;
    # Seed the recursive write.
    my $somebody_is_modified;
    for my $tree ( values %{ $self->{trees} } ) {
        next unless $self->_propagate_modified( $tree, $modified );
        $somebody_is_modified = 1;
    }
    return $somebody_is_modified || $modified;
}

# Recursive helper function.
sub _propagate_modified {
    my ( $self, $class, $modified ) = @_;
    my $file        = $self->{files}{ $class->get_source_class };
    my $source_path = $file->cfh_path( $self->{source} );
    my $h_path      = $file->h_path( $self->{dest} );

    if ( !current( $source_path, $h_path ) ) {
        $modified = 1;
    }

    if ($modified) {
        $file->set_modified($modified);
    }

    # Proceed to the next generation.
    my $somebody_is_modified = $modified;
    for my $kid ( $class->children ) {
        if ( $class->final ) {
            confess(  "Attempt to inherit from final class "
                    . $class->get_class_name . " by "
                    . $kid->get_class_name );
        }
        if ( $self->_propagate_modified( $kid, $modified ) ) {
            $somebody_is_modified = 1;
        }
    }

    return $somebody_is_modified;
}

1;

__END__

__POD__

=head1 NAME

Clownfish::Hierarchy - A class hierarchy.

=head1 DESCRIPTION

A Clownfish::Hierarchy consists of all the classes defined in files within
a source directory and its subdirectories.

There may be more than one tree within the Hierarchy, since all "inert"
classes are root nodes, and since Clownfish does not officially define any
core classes itself from which all instantiable classes must descend.

=head1 METHODS

=head2 new

    my $hierarchy = Clownfish::Hierarchy->new(
        source => undef,    # required
        dest   => undef,    # required
    );

=over

=item * B<source> - The directory we begin reading files from.

=item * B<dest> - The directory where the autogenerated files will be written.

=back

=head2 build

    $hierarchy->build;

Parse every Clownfish header file which can be found under C<source>, building
up the object hierarchy.

=head2 ordered_classes

    my @classes = $hierarchy->ordered_classes;

Return all Classes as a list with the property that every parent class will
precede all of its children.

=head2 propagate_modified

    $hierarchy->propagate_modified($modified);

Visit all File objects in the hierarchy.  If a parent node is modified, mark
all of its children as modified.  

If the supplied argument is true, mark all Files as modified.

=head2 get_source get_dest

Accessors.

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
