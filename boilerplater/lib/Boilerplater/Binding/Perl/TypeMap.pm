use strict;
use warnings;

package Boilerplater::Binding::Perl::TypeMap;
use base qw( Exporter );
use Carp;
use Config;

our @EXPORT_OK = qw( from_perl to_perl );

my %from_perl = (
    double => sub {"$_[0] = SvNV( $_[1] );"},
    float  => sub {"$_[0] = (float)SvNV( $_[1] );"},
    int    => sub {"$_[0] = (int)SvIV( $_[1] );"},
    short  => sub {"$_[0] = (short)SvIV( $_[1] );"},
    long => $Config{longsize} <= $Config{ivsize}
    ? sub {"$_[0] = (long)SvIV( $_[1] );"}
    : sub {"$_[0] = (long)SvNV( $_[1] );"},
    size_t     => sub {"$_[0] = (size_t)SvIV( $_[1] );"},
    chy_u64_t  => sub {"$_[0] = (chy_u64_t)SvNV( $_[1] );"},
    chy_u32_t  => sub {"$_[0] = (chy_u32_t)SvUV( $_[1] );"},
    chy_u16_t  => sub {"$_[0] = (chy_u16_t)SvUV( $_[1] );"},
    chy_u8_t   => sub {"$_[0] = (chy_u8_t)SvUV( $_[1] );"},
    chy_i64_t  => sub {"$_[0] = (chy_i64_t)SvNV( $_[1] );"},
    chy_i32_t  => sub {"$_[0] = (chy_i32_t)SvIV( $_[1] );"},
    chy_i16_t  => sub {"$_[0] = (chy_i16_t)SvIV( $_[1] );"},
    chy_i8_t   => sub {"$_[0] = (chy_i8_t)SvIV( $_[1] );"},
    chy_bool_t => sub {"$_[0] = SvTRUE( $_[1] ) ? 1 : 0;"},
    # Assume that void* is a reference SV -- either a hashref or an arrayref.
    'void*' => sub {
        qq|if (SvROK($_[1])) {
            $_[0] = SvRV($_[1]);
        }
        else {
            $_[0] = NULL; /* avoid uninitialized compiler warning */
            THROW("$_[0] is not a reference");
        }\n|;
    },
);

my %to_perl = (
    double => sub {"$_[0] = newSVnv( $_[1] );"},
    float  => sub {"$_[0] = newSVnv( $_[1] );"},
    int    => sub {"$_[0] = newSViv( $_[1] );"},
    short  => sub {"$_[0] = newSViv( $_[1] );"},
    long => $Config{longsize} <= $Config{ivsize}
    ? sub {"$_[0] = newSViv( $_[1] );"}
    : sub {"$_[0] = newSVnv( (NV)$_[1] );"},
    size_t => sub {"$_[0] = newSViv( $_[1] );"},
    chy_u64_t => $Config{uvsize} == 8 ? sub {"$_[0] = newSVuv( $_[1] );"}
    : sub {"$_[0] = newSVnv( (NV)$_[1] );"},
    chy_u32_t => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_u16_t => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_u8_t  => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_i64_t => $Config{ivsize} == 8 ? sub {"$_[0] = newSViv( $_[1] );"}
    : sub {"$_[0] = newSVnv( (NV)$_[1] );"},
    chy_i32_t  => sub {"$_[0] = newSViv( $_[1] );"},
    chy_i16_t  => sub {"$_[0] = newSViv( $_[1] );"},
    chy_i8_t   => sub {"$_[0] = newSViv( $_[1] );"},
    chy_bool_t => sub {"$_[0] = newSViv( $_[1] );"},
    # Assume that void* is a reference SV -- either a hashref or an arrayref.
    'void*' => sub {"$_[0] = newRV_inc( (SV*)($_[1]) );"},
);

sub _from_bp {
    my ( $bp_var, $c_var, $struct_name ) = @_;
    my $vtable = uc($struct_name);
    if ( $struct_name =~ /^kino_(Obj|ByteBuf|CharBuf)$/ ) {
        return "$bp_var = ($struct_name*)SV_TO_KOBJ_OR_ZCB($c_var, "
            . "&$vtable, &${bp_var}_zcb);";
    }
    else {
        return "$bp_var = ($struct_name*)SV_TO_KOBJ($c_var, &$vtable);";
    }
}

sub _to_bp {
    my ( $c_var, $bp_var, $struct_name ) = @_;
    return "$c_var = $bp_var == NULL ? newSV(0) : "
        . "XSBind_kobj_to_pobj((kino_Obj*)$bp_var);";
}

sub from_perl {
    my ( $type, $bp_var, $c_var ) = @_;
    confess("Not a Boilerplater::Type")
        unless ref($type) && $type->isa('Boilerplater::Type');
    my $type_str = $type->to_c;

    if ( my $sub = $from_perl{$type_str} ) {
        return $sub->( $bp_var, $c_var );
    }

    $type_str =~ s/const\s+//;
    if ( $type_str =~ /^((?:[a-z_]*)[A-Z]\w+)\s*\*\s*$/ ) {
        return _from_bp( $bp_var, $c_var, $1 );
    }

    confess("Missing typemap for '$type_str'");
}

sub to_perl {
    my ( $type, $c_var, $bp_var ) = @_;
    confess("Not a Boilerplater::Type")
        unless ref($type) && $type->isa('Boilerplater::Type');
    my $type_str = $type->to_c;

    if ( my $sub = $to_perl{$type_str} ) {
        return $sub->( $c_var, $bp_var );
    }

    $type_str =~ s/const\s+//;
    if ( $type_str =~ /^((?:[a-z_]*)[A-Z]\w+)\s*\*\s*$/ ) {
        return _to_bp( $c_var, $bp_var, $1 );
    }

    confess("Missing typemap for '$type_str'");
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Perl::TypeMap - Convert between BP and C Perl API.

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
