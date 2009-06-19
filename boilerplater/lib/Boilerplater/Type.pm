use strict;
use warnings;

package Boilerplater::Type;
use Boilerplater::Parcel;
use Boilerplater::Util qw( verify_args );
use Scalar::Util qw( blessed );
use Carp;

our %new_PARAMS = (
    const       => undef,
    specifier   => undef,
    indirection => undef,
    array       => undef,
    parcel      => undef,
    incremented => 0,
    decremented => 0,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless {
        %new_PARAMS,
        is_object   => undef,
        is_floating => undef,
        @_,
        },
        ref($either) || $either;

    # Default indirection level to 0.
    $self->{indirection} ||= 0;

    # Find parcel and parcel prefix.
    if ( !defined $self->{parcel} ) {
        $self->{parcel} = Boilerplater::Parcel->default_parcel;
    }
    elsif ( blessed( $self->{parcel} ) ) {
        confess("Not a Boilerplater::Parcel")
            unless $self->{parcel}->isa('Boilerplater::Parcel');
    }
    else {
        $self->{parcel}
            = Boilerplater::Parcel->singleton( name => $self->{parcel} );
    }
    my $prefix = $self->{parcel}->get_prefix;

    # Validate specifier, use lousy, fragile heuristic to determine whether a
    # type is an object.
    confess("illegal specifier: '$self->{specifier}")
        unless $self->{specifier} =~ /^\w+$/;
    $self->{is_object} = $self->{specifier} =~ /^(?:$prefix)?[A-Z]/ ? 1 : 0;

    # Identify and validate type.
    if (   $self->{is_object}
        || $self->{indirection}
        || $self->{array}
        || $self->{specifier} eq 'void' )
    {
    }
    elsif ( $self->{specifier} =~ /^([iu]\d+|bool)_t$/ ) {
        $self->{is_integer} = 1;
    }
    elsif ( $self->{specifier} =~ /^(?:char|short|int|long)$/ ) {
        $self->{is_integer} = 1;
    }
    elsif ( $self->{specifier} =~ /^(?:float|double)$/ ) {
        $self->{is_floating} = 1;
    }
    elsif ( $self->{specifier} eq 'va_list' ) { }
    elsif ( $self->{specifier} =~ /_t$/ ) { }    # catchall
    else {
        confess("Unknown type specifier: '$self->{specifier}'");
    }

    if ( $self->{specifier} =~ /^[A-Z]/ ) {
        # Add $prefix to what appear to be namespaced types.
        $self->{specifier} = $prefix . $self->{specifier}
            unless $self->{specifier} =~ /^$prefix/;
    }
    elsif ( $self->{specifier} =~ /^([iu]\d+|bool)_t$/ ) {
        # Add chy_ prefix to Charmony integer variables.
        $self->{specifier} = "chy_$self->{specifier}";
    }

    return $self;
}

# Accessors.
sub get_specifier { shift->{specifier} }
sub get_array     { shift->{array} }
sub const         { defined shift->{const} ? 1 : 0 }
sub is_object     { shift->{is_object} }
sub is_integer    { shift->{is_integer} }
sub is_floating   { shift->{is_floating} }
sub incremented   { shift->{incremented} }
sub decremented   { shift->{decremented} }

sub is_string_type {
    my $self = shift;
    return 0 unless $self->{is_object};
    return 0 unless $self->{specifier} =~ /CharBuf/;
    return 1;
}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{indirection} == $other->{indirection};
    return 0 unless $self->{specifier} eq $other->{specifier};
    for (qw( const array incremented decremented )) {
        next unless defined $self->{$_} && defined $other->{$_};
        return 0 unless $self->{$_} eq $other->{$_};
    }
    return 1;
}

# Indicate whether the type is "void".
sub void {
    my $self = shift;
    return 0 if $self->{indirection};
    return 0 unless $self->{specifier} eq 'void';
    return 1;
}

# Return a C stringified version of the type.
#
# Note that the behavior of this method is not consistently C-ish, though it
# is convenient.
#   * Pointers will be included.
#   * Array postfixes will NOT be included.
sub to_c {
    my $self = shift;
    my $string = $self->const ? 'const ' : '';
    $string .= $self->{specifier};
    for ( my $i = 0; $i < $self->{indirection}; $i++ ) {
        $string .= '*';
    }
    return $string;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Type - A primitive or object type.

=head1 METHODS

=head2 new

    my $type = Boilerplater::Type->new(
        specifier   => 'char',    # required
        indirection => undef,     # default 0
        array       => '[]',      # default undef,
        const       => 1,         # default undef
        incremented => 1,         # default 0
    );

=over

=item *

B<specifier> - The name of the type, not including any indirection or array
subscripts.  If the type begins with a capital letter, it will be assumed to
be an object type.

=item *

B<indirection> - integer indicating level of indirection. Example: the C type
"float**" has a specifier of "float" and indirection 2.

=item *

B<array> - A string describing an array postfix.  

=item *

B<const> - should be 1 if the type is const.

=item *

B<incremented> - Indicates that the variable is having its refcount
incremented by a function, meaning that the caller must take responsibility
for the additional refcount.

=item *

B<decremented> - Indicates that the variable is having its refcount
decremented by a function, meaning that the caller must take responsibility
for the loss of one refcount.

=back

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
