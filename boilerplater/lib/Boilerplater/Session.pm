use strict;
use warnings;

package Boilerplater::Session;
use Carp;
use File::Find qw( find );
use File::Spec::Functions qw( catfile splitpath );
use File::Path qw( mkpath );
use Fcntl;

use Boilerplater::Util qw( slurp_file current verify_args );
use Boilerplater::Class;
use Boilerplater::Class::Final;
use Boilerplater::Parser;

our %new_PARAMS = (
    base_dir => undef,
    dest_dir => undef,
    header   => undef,
    footer   => undef,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless {
        parser => Boilerplater::Parser->new,
        trees  => {},
        files  => {},
        %new_PARAMS,
        @_,
        },
        ref($either) || $either;

    # Validate.
    for (qw( base_dir dest_dir header footer )) {
        confess("$_ is mandatory") unless defined $self->{$_};
    }

    return $self;
}

# Accessors.
sub get_base_dir { shift->{base_dir} }
sub get_dest_dir { shift->{dest_dir} }
sub get_header   { shift->{header} }
sub get_footer   { shift->{footer} }

# Return flattened hierarchies.
sub ordered_classes {
    my $self = shift;
    my @all;
    for my $tree ( values %{ $self->{trees} } ) {
        push @all, $tree->tree_to_ladder;
    }
    return @all;
}

# Slurp all .bp files.
# Arrange the class objects into inheritance trees.
sub build {
    my $self = shift;
    $self->_parse_bp_files;
    $_->grow_tree for values %{ $self->{trees} };
}

sub _parse_bp_files {
    my $self = shift;
    my ( $base_dir, $dest_dir ) = @{$self}{qw( base_dir dest_dir )};

    # Collect filenames.
    my @all_source_paths;
    find(
        {   wanted => sub {
                if ( $File::Find::name =~ /\.bp$/ ) {
                    push @all_source_paths, $File::Find::name
                        unless /#/;    # skip emacs .#filename.h lock files
                }
            },
            no_chdir => 1,
            follow   => 1,    # follow symlinks if possible (noop on Windows)
        },
        $self->{base_dir},
    );

    # Process any file that has at least one class declaration.
    my %classes;
    for my $source_path (@all_source_paths) {
        # Derive the name of the class that owns the module file.
        my $source_class = $source_path;
        $source_class =~ s/\.bp$//;
        $source_class =~ s/^\Q$base_dir\E\W*//
            or die "'$source_path' doesn't start with '$base_dir'";
        $source_class =~ s/\W/::/g;

        # Slurp, parse, add parsed file to pool.
        my $content = slurp_file($source_path);
        $content = $self->{parser}->strip_plain_comments($content);
        my $file = $self->{parser}
            ->file( $content, 0, source_class => $source_class, );
        confess("parse error for $source_path") unless defined $file;
        $self->{files}{$source_class} = $file;
        for my $class ( $file->get_classes ) {
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

sub write_all_modified {
    my ( $self, $modified ) = @_;

    # Seed the recursive write.
    for my $tree ( values %{ $self->{trees} } ) {
        $modified = $self->_propagate_modified( $tree, $modified );
    }

    my %written;
    while ( my ( $source_class, $file ) = each %{ $self->{files} } ) {
        next unless $file->get_modified;
        next if $written{$source_class};
        $written{$source_class} = 1;
        $file->write_h(
            dest_dir => $self->{dest_dir},
            header   => $self->{header},
            footer   => $self->{footer},
        );
        $file->write_c(
            dest_dir => $self->{dest_dir},
            header   => $self->{header},
            footer   => $self->{footer},
        );
    }

    return $modified;
}

# Recursive helper function.
sub _propagate_modified {
    my ( $self, $class, $modified ) = @_;
    my $file        = $self->{files}{ $class->get_source_class };
    my $source_path = $file->bp_path( $self->{base_dir} );
    my $h_path      = $file->h_path( $self->{dest_dir} );

    if ( !current( $source_path, $h_path ) ) {
        $modified = 1;
    }

    if ($modified) {
        $file->set_modified($modified);
    }

    # Proceed to the next generation.
    my $somebody_is_modified = $modified;
    for my $kid ( $class->get_children ) {
        if ( $class->is_final ) {
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

sub write_boil_h {
    my $self     = shift;
    my @ordered  = $self->ordered_classes;
    my $typedefs = "";

    for my $class (@ordered) {
        next if $class->inert;
        my $struct = $class->get_struct_name;
        my $prefix = $class->get_prefix;
        $typedefs .= "typedef struct $prefix$struct $prefix$struct;\n";
    }
    my $filepath = catfile( $self->{dest_dir}, "boil.h" );
    unlink $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY )
        or confess("Can't open '$filepath': $!");
    print $fh <<END_STUFF;
$self->{header}
#ifndef BOIL_H
#define BOIL_H 1

#include <stddef.h>
#include "charmony.h"

$typedefs

/* Refcount / host object */
typedef union {
    size_t  count;
    void   *host_obj;
} boil_ref_t;

/* Generic method pointer.
 */
typedef void
(*boil_method_t)(const void *vself);

/* Access the function pointer for a given method from the vtable.
 */
#define KINO_METHOD(_vtable, _class_nick, _meth_name) \\
     kino_method(_vtable, \\
     Kino_ ## _class_nick ## _ ## _meth_name ## _OFFSET)

static CHY_INLINE boil_method_t
kino_method(const void *vtable, size_t offset) 
{
    union { char *cptr; boil_method_t *fptr; } ptr;
    ptr.cptr = (char*)vtable + offset;
    return ptr.fptr[0];
}

/* Access the function pointer for the given method in the superclass's
 * vtable. */
#define KINO_SUPER_METHOD(_vtable, _class_nick, _meth_name) \\
     kino_super_method(_vtable, \\
     Kino_ ## _class_nick ## _ ## _meth_name ## _OFFSET)

extern size_t kino_VTable_offset_of_parent;
static CHY_INLINE boil_method_t
kino_super_method(const void *vtable, size_t offset) 
{
    char *vt_as_char = (char*)vtable;
    kino_VTable **parent_ptr 
        = (kino_VTable**)(vt_as_char + kino_VTable_offset_of_parent);
    return kino_method(*parent_ptr, offset);
}

/* Return a boolean indicating whether a method has been overridden.
 */
#define KINO_OVERRIDDEN(_self, _class_nick, _meth_name, _micro_name) \\
        (kino_method(_self->vtable, \\
            Kino_ ## _class_nick ## _ ## _meth_name ## _OFFSET )\\
            != (boil_method_t)kino_ ## _class_nick ## _ ## _micro_name )

#ifdef KINO_USE_SHORT_NAMES
  #define METHOD                   KINO_METHOD
  #define SUPER_METHOD             KINO_SUPER_METHOD
  #define OVERRIDDEN               KINO_OVERRIDDEN
#endif

typedef struct kino_Callback {
    const char    *name;
    size_t         name_len;
    boil_method_t  func;
    size_t         offset;
} kino_Callback;

#define KINO_CALLBACK_DEC(_name, _func, _offset) \\
    { _name, sizeof(_name) - 1, (boil_method_t)_func, _offset }

#define BOIL_THROW KINO_THROW
#define BOIL_ERR   KINO_ERR

#endif /* BOIL_H */

$self->{footer}

END_STUFF
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Session - A compilation session.

=head1 METHODS

=head2 new

    my $session = Boilerplater::Session->new(
        base_dir => undef,    # required
        dest_dir => undef,    # required
        header   => undef,    # required
        footer   => undef,    # required
    );

=over

=item *

B<base_dir> - The directory we begin reading files from.

=item *

B<dest_dir> - The directory we write C header output files to.

=item *

B<header> - Text which will be prepended to each generated C file --
typically, an "autogenerated file" warning.

=item *

B<footer> - Text to be appended to the end of each generated C file --
typically copyright information.

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
