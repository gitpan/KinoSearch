use strict;
use warnings;

package Boilerplater::Class;
use base qw( Boilerplater::Symbol );
use Carp;
use Config;
use Boilerplater::Function;
use Boilerplater::Method;
use Boilerplater::Util qw(
    verify_args
    a_isa_b
);
use Boilerplater::Dumpable;
use File::Spec::Functions qw( splitpath catfile );
use Scalar::Util qw( reftype );

our %new_PARAMS = (
    source_class      => undef,
    class_name        => undef,
    cnick             => undef,
    parent_class_name => undef,
    methods           => undef,
    functions         => undef,
    member_vars       => undef,
    static_vars       => undef,
    docu_comment      => undef,
    static            => undef,
    parcel            => undef,
    attributes        => undef,
    exposure          => 'parcel',
);

my $dumpable = Boilerplater::Dumpable->new;

our %registry;

# Testing only.
sub _zap { delete $registry{ +shift } }

our %fetch_singleton_PARAMS = (
    parcel     => undef,
    class_name => undef,
);

sub fetch_singleton {
    my ( undef, %args ) = @_;
    verify_args( \%fetch_singleton_PARAMS, %args ) or confess $@;

    # Acquire a Parcel.
    my $parcel = $args{parcel};
    if ( !defined $parcel ) {
        $parcel = Boilerplater::Parcel->default_parcel;
    }
    elsif ( blessed($parcel) ) {
        confess("Not a Boilerplater::Parcel")
            unless $parcel->isa('Boilerplater::Parcel');
    }
    else {
        $parcel = Boilerplater::Parcel->singleton( name => $args{parcel} );
    }

    # Get the class identifier.
    my $class_name = $args{class_name};
    confess("Missing required param 'class_name'") unless defined $class_name;
    $class_name =~ /(\w+)$/ or confess("No match");
    my $class_identifier = $1;

    my $key = $parcel->get_prefix . $class_identifier;
    return $registry{$key};
}

sub new { confess("The constructor for Boilerplater::Class is create()") }

sub create {
    my $class_class = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = $class_class->SUPER::new(
        %new_PARAMS,
        struct_name       => undef,
        methods           => [],
        overridden        => {},
        functions         => [],
        member_vars       => [],
        novel_member_vars => undef,
        children          => [],
        parent            => undef,
        attributes        => {},
        autocode          => '',
        @_
    );

    # Keep track of member vars defined by this class rather than inherited.
    $self->{novel_member_vars} = [ @{ $self->{member_vars} } ];

    # Make it possible to look up methods and functions by name.
    $self->{meth_by_name}{ $_->micro_sym } = $_ for $self->get_methods;
    $self->{func_by_name}{ $_->micro_sym } = $_ for $self->get_functions;

    # Verify class name, derive struct name and possibly cnick as well.
    confess("Invalid class name")
        unless $self->{class_name}
            =~ /^([A-Z][A-Za-z0-9]*)(::[A-Z][A-Za-z0-9]*)*$/;
    $self->{class_name} =~ /(\w+)$/;
    $self->{struct_name} = $1;
    $self->{cnick} = $1 unless defined $self->{cnick};

    # Verify that members of supplied arrays meet "is a" requirements.
    for ( @{ $self->{functions} } ) {
        confess("Not a Boilerplater::Function")
            unless a_isa_b( $_, 'Boilerplater::Function' );
    }
    for ( @{ $self->{methods} } ) {
        confess("Not a Boilerplater::Method")
            unless a_isa_b( $_, 'Boilerplater::Method' );
    }
    for ( @{ $self->{member_vars} }, @{ $self->{static_vars} } ) {
        confess("Not a Boilerplater::Variable")
            unless a_isa_b( $_, 'Boilerplater::Variable' );
    }

    # Assume that Foo::Bar should be found in Foo/Bar.h.
    $self->{source_class} = $self->{class_name}
        unless defined $self->{source_class};

    # Validate attributes.
    confess("Param 'attributes' not a hashref")
        unless reftype( $self->{attributes} ) eq 'HASH';

    # Store in registry.
    my $key      = $self->get_prefix . $self->{struct_name};
    my $existing = $registry{$key};
    if ($existing) {
        confess(  "New class $self->{class_name} conflicts with previously "
                . "compiled class $existing->{class_name}" );
    }
    $registry{$key} = $self;

    return $self;
}

#     # /path/to/Foo/Bar.c, if source class is Foo::Bar.
#     my $path = $class->file_path( '/path/to', '.c' );
#
# Provide an OS-specific path for a file relating to this class could be
# found, by joining together the components of the "source class" name.
sub file_path {
    my ( $self, $base_dir, $ext ) = @_;
    my @components = split( '::', $self->{source_class} );
    unshift @components, $base_dir
        if defined $base_dir;
    $components[-1] .= $ext;
    return catfile(@components);
}

# Return a relative path to a C header file, appropriately formatted for a
# pound-include directive.
sub include_h {
    my $self = shift;
    my @components = split( '::', $self->{source_class} );
    $components[-1] .= '.h';
    return join( '/', @components );
}

# Accessors.
sub is                    { exists $_[0]->{attributes}{ $_[1] } }
sub get_cnick             { shift->{cnick} }
sub get_class_name        { shift->{class_name} }
sub get_struct_name       { shift->{struct_name} }
sub get_parent_class_name { shift->{parent_class_name} }
sub get_source_class      { shift->{source_class} }
sub get_docu_comment      { shift->{docu_comment} }
sub get_functions         { @{ shift->{functions} } }
sub get_methods           { @{ shift->{methods} } }
sub get_member_vars       { @{ shift->{member_vars} } }
sub novel_member_vars     { @{ shift->{novel_member_vars} } }
sub get_static_vars       { @{ shift->{static_vars} } }
sub get_children          { @{ shift->{children} } }
sub get_parent            { shift->{parent} }
sub get_autocode          { shift->{autocode} }
sub static                { shift->{static} }

sub set_parent { $_[0]->{parent} = $_[1] }

# Append auxiliary C code.
sub append_autocode { $_[0]->{autocode} .= $_[1] }

# The name of the global VTable object for this class.
sub vtable_var { uc( shift->{struct_name} ) }

# The C type specifier for this class's vtable.  Each vtable needs to have its
# own type because each has a variable number of methods at the end of the
# struct, and it's not possible to initialize a static struct with a flexible
# array at the end under C89.
sub vtable_type { shift->vtable_var . '_VT' }

# Return the Method object for the supplied micro_sym, if any.
sub method {
    my ( $self, $micro_sym ) = @_;
    return $self->{meth_by_name}{ lc($micro_sym) };
}

sub novel_method {
    my ( $self, $micro_sym ) = @_;
    my $method = $self->{meth_by_name}{ lc($micro_sym) };
    if ( defined $method and $method->get_class_cnick eq $self->{cnick} ) {
        return $method;
    }
    else {
        return;
    }
}

# Return the Function object for the supplied micro_sym, if any.
sub function {
    my ( $self, $micro_sym ) = @_;
    return $self->{func_by_name}{ lc($micro_sym) };
}

# Inheriting is allowed.
sub is_final {0}

# Add a child to this class.
sub add_child {
    my ( $self, $child ) = @_;
    push @{ $self->{children} }, $child;
}

# Add a method to the class.  Valid only before _bequeath_methods is called.
sub add_method {
    my ( $self, $method ) = @_;
    push @{ $self->{methods} }, $method;
    $self->{meth_by_name}{ $method->micro_sym } = $method;
}

# Create dumpable functions unless hand coded versions were supplied.
sub _create_dumpables {
    my $self = shift;
    $dumpable->add_dumpables($self) if $self->is('dumpable');
}

# Bequeath all inherited methods and members to children.
sub grow_tree {
    my $self = shift;
    $self->_establish_parentage;
    $self->_bequeath_member_vars;
    $self->_generate_automethods;
    $self->_bequeath_methods;
}

# Let the children know who their parent class is.
sub _establish_parentage {
    my $self = shift;
    for my $child ( @{ $self->{children} } ) {
        # This is a circular reference and thus a memory leak, but we don't
        # care, because we have to have everything in memory at once anyway.
        $child->{parent} = $self;
        $child->_establish_parentage;
    }
}

# Pass down member vars to from parent to children.
sub _bequeath_member_vars {
    my $self = shift;
    for my $child ( @{ $self->{children} } ) {
        unshift @{ $child->{member_vars} }, @{ $self->{member_vars} };
        $child->_bequeath_member_vars;
    }
}

# Create auto-generated methods.  This must be called after member vars are
# passed down but before methods are passed down.
sub _generate_automethods {
    my $self = shift;
    $self->_create_dumpables;
    for my $child ( @{ $self->{children} } ) {
        $child->_generate_automethods;
    }
}

sub _bequeath_methods {
    my $self = shift;

    for my $child ( @{ $self->{children} } ) {
        # Pass down methods, with some being overridden.
        my @common_methods;    # methods which child inherits or overrides
        for my $method ( @{ $self->{methods} } ) {
            if ( exists $child->{meth_by_name}{ $method->micro_sym } ) {
                my $child_method
                    = $child->{meth_by_name}{ $method->micro_sym };
                $child_method->override($method);
                push @common_methods, $child_method;
            }
            else {
                $child->{meth_by_name}{ $method->micro_sym } = $method;
                push @common_methods, $method;
            }
        }

        # Create array of methods, preserving exact order so vtables match up.
        my @new_method_set;
        my %seen;
        for my $meth ( @common_methods, @{ $child->{methods} } ) {
            next if $seen{ $meth->micro_sym };
            $seen{ $meth->micro_sym } = 1;
            $meth = $meth->finalize if $child->is_final;
            push @new_method_set, $meth;
        }
        $child->{methods} = \@new_method_set;

        # Pass it all down to the next generation.
        $child->_bequeath_methods;
    }
}

# Collect non-inherited methods.
sub novel_methods {
    my $self = shift;
    return
        grep { $_->get_class_cnick eq $self->{cnick} } @{ $self->{methods} };
}

# Return this class and all its child classes as an array, where all children
# appear after their parent nodes.
sub tree_to_ladder {
    my $self   = shift;
    my @ladder = ($self);
    for my $child ( @{ $self->{children} } ) {
        push @ladder, $child->tree_to_ladder;
    }
    return @ladder;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Class - An object representing a single class definition.

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
