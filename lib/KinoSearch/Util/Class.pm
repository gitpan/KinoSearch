use strict;
use warnings;

package KinoSearch::Util::Class;
use KinoSearch::Util::ToolSet;

our %instance_vars = ();

sub new {
    my $class = shift;    # leave the rest of @_ intact.

    # find a defaults hash and verify args
    $class = ref($class) || $class;
    my $defaults = _retrieve_hashref("$class\::instance_vars");

    if ( !defined $defaults or !verify_args( $defaults, @_ ) ) {
        confess kerror() if $class =~ /^KinoSearch/;

        # if a user-based subclass, find KinoSearch parent class and verify.
        my $kinoclass = _traverse_at_isa($class);
        confess kerror() unless $kinoclass;
        $defaults = _retrieve_hashref("$kinoclass\::instance_vars");
        confess kerror() unless verify_args( $defaults, @_ );
    }

    # merge var => val pairs into new object, call customizable init routine
    my $self = bless { %$defaults, @_ }, $class;
    $self->init_instance;

    return $self;
}

# Walk @ISA until a parent class starting with 'KinoSearch::' is found.
sub _traverse_at_isa {
    my $orig = shift;
    {
        no strict 'refs';
        my $at_isa = \@{ $orig . '::ISA' };
        for my $parent (@$at_isa) {
            return $parent if $parent =~ /^KinoSearch::/;
            my $grand_parent = _traverse_at_isa($parent);
            return $grand_parent if $grand_parent;
        }
    };
    return '';
}

sub init_instance { }

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

sub CLONE {
    my $package = shift;
    confess(  "CLONE invoked by package '$package', indicating initiation of "
            . "either threads or Win32 fork, but KinoSearch is not thread-safe"
    );
}

sub ready_set {
    my $package = shift;
    no strict 'refs';
    for my $member (@_) {
        *{ $package . "::set_$member" } = sub { $_[0]->{$member} = $_[1] };
    }
}

sub abstract_death {
    my ( undef, $filename, $line, $methodname ) = caller(1);
    die "ERROR: $methodname', called at $filename line $line, is an "
        . "abstract method and must be defined in a subclass";
}

sub todo_death {
    my ( undef, $filename, $line, $methodname ) = caller(1);
    die "ERROR: $methodname, called at $filename line $line, is not "
        . "implemented yet in KinoSearch, but is on the todo list";
}

sub hash_code { refaddr(shift) }

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::Class

SV*
_retrieve_hashref(name)
    const char *name;
CODE:
{
    HV* fields_hash = get_hv(name, 0);
    RETVAL = fields_hash == NULL
        ? newSV(0)
        : newRV_inc((SV*)fields_hash);
}
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Util::Class - Class-building utility.

=head1 PRIVATE CLASS

This is a private class and the interface may change radically and without
warning.  Do not use it on its own.

=head1 SYNOPSIS

    package KinoSearch::SomePackage::SomeClass;
    use base qw( KinoSearch::Util::Class );
    
    our %instance_vars = (
        # constructor params / members
        foo => undef,
        bar => 10,

        # members
        baz => '',
    );

=head1 DESCRIPTION

KinoSearch::Util::Class is a class-building utility a la L<Class::Accessor>,
L<Class::Meta>, etc.  It provides three main services:

=over

=item 1

A constructor with basic argument checking.

=item 2

Manufacturing of get_xxxx and set_xxxx methods.

=item 3 

Convenience methods which help in defining abstract classes.

=back

=head1 VARIABLES

=head2 %instance_vars

Each class which uses the inherited constructor needs to define an
%instance_vars hash as a package global, which serves as a template
for the creation of a hash-based object.  

    our %instance_vars = (
        # constructor params / members
        foo => undef,
        bar => 10,

        # members
        baz => '',
    );

%instance_vars may only contain scalar values, as the defaults are merged
into the object using a shallow copy.

=head1 METHODS

=head2 new

A generic constructor with basic argument checking.  new() expects hash-style
labeled parameters; the label names must be present in the %instance_vars
hash, or it will confess().

After verifying the labeled parameters, new() merges %instance_vars and @_
into a new object.  It then calls $self->init_instance() before returning the
blessed reference.

=head2 init_instance

    $self->init_instance();

Perform customized initialization routine.  By default, this is a no-op.

=head2 ready_get_set ready_get ready_set

    # create get_foo(), set_foo(), get_bar(), set_bar() in __PACKAGE__
    BEGIN { __PACKAGE__->ready_get_set(qw( foo bar )) };

Mass manufacture getters and setters.  The setters do not return a meaningful
value.

=head2 abstract_death todo_death

    sub an_abstract_method      { shift->abstract_death }
    sub maybe_someday           { shift->todo_death }

These are just different ways to die(), and are of little interest until your
particular application comes face to face with one of them.  

abstract_death indicates that a method must be defined in a subclass.

todo_death indicates a feature that might get implemented someday.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut

