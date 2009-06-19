use strict;
use warnings;

package Boilerplater::Type::Primitive;
use base qw( Boilerplater::Type );
use Boilerplater::Util qw( verify_args );
use Carp;

our %new_PARAMS = (
    const     => undef,
    specifier => undef,
);

our %specifiers = (
    bool_t => 'integer',
    i8_t   => 'integer',
    i16_t  => 'integer',
    i32_t  => 'integer',
    i64_t  => 'integer',
    u8_t   => 'integer',
    u16_t  => 'integer',
    u32_t  => 'integer',
    u64_t  => 'integer',
    char   => 'integer',
    int    => 'integer',
    short  => 'integer',
    long   => 'integer',
    float  => 'float',
    double => 'float',
);

sub new {
    my ( $either, %args ) = @_;
    verify_args( \%new_PARAMS, %args ) or confess $@;

    my $int_or_float = $specifiers{ $args{specifier} };
    confess("Unknown specifier: '$args{specifier}'")
        unless $int_or_float;

    my $self = bless {
        %new_PARAMS,
        is_floating => $int_or_float eq 'float'   ? 1 : 0,
        is_integer  => $int_or_float eq 'integer' ? 1 : 0,
        %args
        },
        ref($either) || $either;

    # Cache the C representation of this type.
    $self->{_c_string} = $self->const ? 'const ' : '';
    if ( $self->{specifier} =~ /^(?:[iu]\d+|bool)_t$/ ) {
        $self->{_c_string} .= "chy_";
    }
    $self->{_c_string} .= $self->{specifier};

    return $self;
}

# Accessors.
sub get_specifier { shift->{specifier} }
sub const         { shift->{const} }
sub is_object     {0}
sub is_integer    { shift->{is_integer} }
sub is_floating   { shift->{is_floating} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{specifier} eq $other->{specifier};
    return 0 if ( $self->{const} xor $other->{const} );
    return 1;
}

sub to_c { shift->{_c_string} }

1;

__END__

