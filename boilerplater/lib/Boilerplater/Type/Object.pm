use strict;
use warnings;

package Boilerplater::Type::Object;
use base qw( Boilerplater::Type );
use Boilerplater::Parcel;
use Boilerplater::Util qw( verify_args );
use Scalar::Util qw( blessed );
use Carp;

our %new_PARAMS = (
    const       => undef,
    specifier   => undef,
    indirection => 1,
    parcel      => undef,
    incremented => 0,
    decremented => 0,
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = bless { %new_PARAMS, @_, }, ref($either) || $either;

    # Validate indirection.
    confess("Indirection must be 1") unless $self->{indirection} == 1;

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

    # Validate specifier.
    confess("illegal specifier: '$self->{specifier}")
        unless $self->{specifier}
            =~ /^(?:$prefix)?[A-Z][A-Za-z0-9]*[a-z]+[A-Za-z0-9]*(?!\w)/;

    # Add $prefix if necessary.
    $self->{specifier} = $prefix . $self->{specifier}
        unless $self->{specifier} =~ /^$prefix/;

    return $self;
}

# Accessors.
sub const       { shift->{const} }
sub void        {0}
sub is_object   {1}
sub is_integer  {0}
sub is_floating {0}
sub incremented { shift->{incremented} }
sub decremented { shift->{decremented} }

sub is_string_type {
    my $self = shift;
    return 0 unless $self->{specifier} =~ /CharBuf/;
    return 1;
}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{specifier} eq $other->{specifier};
    for (qw( const incremented decremented )) {
        return 0 if ( $self->{$_} xor $other->{$_} );
    }
    return 1;
}

sub to_c {
    my $self = shift;
    my $string = $self->const ? 'const ' : '';
    $string .= "$self->{specifier}*";
    return $string;
}

1;

__END__
