package KinoSearch::Util::Class;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;

use Clone 'clone';
use KinoSearch::Util::VerifyArgs qw( verify_args );

our %instance_vars = ();

sub new {
    my $class = shift;    # leave the rest of @_ intact.

    # clone the instance_vars hash and bless it
    $class = ref($class) || $class;
    my $defaults;
    {
        no strict 'refs';
        $defaults = \%{ $class . '::instance_vars' };
    }
    my $self = clone($defaults);
    bless $self, $class;

    # verify argument labels and merge var => val pairs into object
    verify_args( $defaults, @_ );
    %$self = ( %$self, @_ );

    # call customizable initialization routine
    $self->init_instance;

    return $self;
}

sub init_instance { }

sub init_instance_vars {
    my $package = shift;

    # return %PARENT_CLASS::instance_vars plus args as a flat list
    no strict 'refs';
    my $first_isa = ${ $package . '::ISA' }[0];
    return ( %{ $first_isa . '::instance_vars' }, @_ );
}

sub ready_get_set {
    ready_get(@_);
    ready_set(@_);
}

sub ready_get {
    my $package = shift;
    no strict 'refs';
    for my $member (@_) {
        *{ $package . "::get_$member" } = sub { return $_[0]->{$member} };
    }
}

sub ready_set {
    my $package = shift;
    no strict 'refs';
    for my $member (@_) {
        *{ $package . "::set_$member" } = sub { $_[0]->{$member} = $_[1] };
    }
}

=for Rationale:
KinoSearch is not thread-safe.  Among other things, the C-struct-based classes
cause segfaults or bus errors when their data gets double-freed by DESTROY.
Therefore, CLONE dies with a user-friendly error message before that happens.

=cut

sub CLONE {
    my $package = shift;
    die(      "CLONE invoked by package '$package', indicating that threads "
            . "or Win32 fork were initiated, but KinoSearch is not thread-safe"
    );
}

sub abstract_death {
    my ( undef, $filename, $line, $methodname ) = caller(1);
    die "ERROR: $methodname', called at $filename line $line, is an "
        . "abstract method and must be defined in a subclass";
}

sub unimplemented_death {
    my ( undef, $filename, $line, $methodname ) = caller(1);
    die "ERROR: $methodname, called at $filename line $line, is "
        . "intentionally unimplemented in KinoSearch, though it is part "
        . "of Lucene";
}

sub todo_death {
    my ( undef, $filename, $line, $methodname ) = caller(1);
    die "ERROR: $methodname, called at $filename line $line, is not "
        . "implemented yet in KinoSearch, but is on the todo list";
}

1;

__END__

=head1 NAME

KinoSearch::Util::Class - class building utility

=head1 PRIVATE CLASS

This is a private class and the interface may change radically and without
warning.  Do not use it on its own.

=head1 SYNOPSIS

    package KinoSearch::SomePackage::SomeClass;
    use base qw( KinoSearch::Util::Class );

    our %instance_vars = __PACKAGE__->init_instance_vars(
        # constructor params / members
        foo => undef,
        bar => {},

        # members
        baz => {},
    );

=head1 DESCRIPTION

KinoSearch::Util::Class is a class-building utility a la
L<Class::Accessor|Class::Accessor>, L<Class::Meta|Class::Meta>, etc.  It
provides three main services:

=over

=item 1 

A mechanism for inheriting instance variable declarations.

=item 2 

A constructor with basic argument checking.

=item 3 

Convenience methods which help in defining abstract classes.

=back

=head1 VARIABLES

=head2 %instance_vars

The %instance_vars hash, which is always a package global, serves as a
template for the creation of a hash-based object.  It is built up from all the
%instance_vars hashes in the module's parent classes, using
init_instance_vars().

Key-value pairs in an %instance_vars hash are labeled as "constructor params"
and/or "members".  Items which are labeled as constructor params can be used
as arguments to new().

    our %instance_vars = __PACKAGE__->init_instance_vars(
        # constructor params / members
        foo => undef,
        bar => {},
        # members
        baz => '',
    );
    
    # ok: specifies foo, uses default for bar, derives baz
    my $object = __PACKAGE__->new( foo => $foo );

    # not ok: baz isn't a constructor param
    my $object = __PACKAGE__->new( baz => $baz );

    # ok if a parent class defines boffo as a constructor param
    my $object = __PACKAGE__->new( 
        foo   => $foo,
        boffo => $boffo,
    );

%instance_vars can contain hashrefs, array-refs, and full-fledged Perl
objects.  However, it cannot contain C-struct based objects, since
L<Clone|Clone>'s clone() method doesn't know how to duplicate those safely.

    # ok, Lock is a Perl object
    our %instance_vars = __PACKAGE__->init_instance_vars(
        # members
        term => KinoSearch::Store::Lock->new,
    );

    # BAD! causes memory errors, since TermInfo is a C-struct object
    our %instance_vars = __PACKAGE__->init_instance_vars(
        # members
        tinfo => KinoSearch::Index::TermInfo->new,
    );

=head1 METHODS

=head2 new

A generic constructor with basic argument checking.  new() expects hash-style
labeled parameters; the label names must be present in the %instance_vars
hash, or it will croak().

After verifying the labeled parameters, new() creates a deep clone of
%instance_vars, and merges in the labeled arguments.  It then calls
$self->init_instance() before returning the blessed reference.

=head2 init_instance

    $self->init_instance();

Perform customized initialization routine.  By default, this is a no-op.

=head2 init_instance_vars

    our %instance_vars = __PACKAGE__->init_instance_vars(
        a_safe_variable_name_that_wont_clash => 1,
        freep_warble                         => undef,
    );

Package method only.  Return a flat list containing the arguments, plus all
the key-value pairs in the parent class's %instance_vars hash.

=head2 abstract_death unimplemented_death todo_death

    sub an_abstract_method      { shift->abstract_death }
    sub an_unimplemented_method { shift->unimplemented_death }
    sub maybe_someday           { shift->todo_death }

These are just different ways to die(), and are of little interest until your
particular application comes face to face with one of them.  

abstract_death indicates that a method must be defined in a subclass.

unimplemented_death indicates a feature/function that will probably not be
implemented.  Typically, this would appear for a sub that a developer
intimately familiar with Lucene would expect to find.

todo_death indicates a feature that might get implemented someday.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=cut

