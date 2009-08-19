use strict;
use warnings;

package Boilerplater::Binding::Perl::TypeMap;
use base qw( Exporter );
use Scalar::Util qw( blessed );
use Carp;
use Config;

our @EXPORT_OK = qw( from_perl to_perl );

# Convert from a Perl scalar to a primitive type.
my %primitives_from_perl = (
    double => sub {"$_[0] = SvNV( $_[1] );"},
    float  => sub {"$_[0] = (float)SvNV( $_[1] );"},
    int    => sub {"$_[0] = (int)SvIV( $_[1] );"},
    short  => sub {"$_[0] = (short)SvIV( $_[1] );"},
    long   => sub {
        $Config{longsize} <= $Config{ivsize}
            ? "$_[0] = (long)SvIV( $_[1] );"
            : "$_[0] = (long)SvNV( $_[1] );";
    },
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
);

# Convert from a primitive type to a Perl scalar.
my %primitives_to_perl = (
    double => sub {"$_[0] = newSVnv( $_[1] );"},
    float  => sub {"$_[0] = newSVnv( $_[1] );"},
    int    => sub {"$_[0] = newSViv( $_[1] );"},
    short  => sub {"$_[0] = newSViv( $_[1] );"},
    long   => sub {
        $Config{longsize} <= $Config{ivsize}
            ? "$_[0] = newSViv( $_[1] );"
            : "$_[0] = newSVnv( (NV)$_[1] );";
    },
    size_t    => sub {"$_[0] = newSViv( $_[1] );"},
    chy_u64_t => sub {
        $Config{uvsize} == 8
            ? "$_[0] = newSVuv( $_[1] );"
            : "$_[0] = newSVnv( (NV)$_[1] );";
    },
    chy_u32_t => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_u16_t => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_u8_t  => sub {"$_[0] = newSVuv( $_[1] );"},
    chy_i64_t => sub {
        $Config{ivsize} == 8
            ? "$_[0] = newSViv( $_[1] );"
            : "$_[0] = newSVnv( (NV)$_[1] );";
    },
    chy_i32_t  => sub {"$_[0] = newSViv( $_[1] );"},
    chy_i16_t  => sub {"$_[0] = newSViv( $_[1] );"},
    chy_i8_t   => sub {"$_[0] = newSViv( $_[1] );"},
    chy_bool_t => sub {"$_[0] = newSViv( $_[1] );"},
);

# Extract a Boilerplater object from a Perl SV.
sub _sv_to_bp_obj {
    my ( $type, $bp_var, $xs_var, $stack_var ) = @_;
    my $struct_name = $type->get_specifier;
    my $vtable      = uc($struct_name);
    if ( $struct_name =~ /^[a-z_]*(Obj|ByteBuf|CharBuf)$/ ) {
        # Share buffers rather than copy between Perl scalars and BP string
        # types.  Assume that the appropriate ZombieCharBuf has been declared
        # on the stack.
        return "$bp_var = ($struct_name*)XSBind_sv_to_kobj_or_zcb($xs_var, "
            . "$vtable, &$stack_var);";
    }
    else {
        return
            "$bp_var = ($struct_name*)XSBind_sv_to_kobj($xs_var, $vtable);";
    }
}

sub _void_star_to_bp {
    my ( $type, $bp_var, $xs_var ) = @_;
    # Assume that void* is a reference SV -- either a hashref or an arrayref.
    return qq|if (SvROK($xs_var)) {
            $bp_var = SvRV($xs_var);
        }
        else {
            $bp_var = NULL; /* avoid uninitialized compiler warning */
            BOIL_THROW(BOIL_ERR, "$bp_var is not a reference");
        }\n|;
}

sub from_perl {
    my ( $type, $bp_var, $xs_var, $stack_var ) = @_;
    confess("Not a Boilerplater::Type")
        unless blessed($type) && $type->isa('Boilerplater::Type');

    if ( $type->is_object ) {
        return _sv_to_bp_obj( $type, $bp_var, $xs_var, $stack_var );
    }

    if ( $type->is_primitive ) {
        if ( my $sub = $primitives_from_perl{ $type->to_c } ) {
            return $sub->( $bp_var, $xs_var );
        }
    }
    elsif ( $type->is_composite ) {
        if ( $type->to_c eq 'void*' ) {
            return _void_star_to_bp( $type, $bp_var, $xs_var );
        }
    }

    confess( "Missing typemap for " . $type->to_c );
}

sub to_perl {
    my ( $type, $xs_var, $bp_var ) = @_;
    confess("Not a Boilerplater::Type")
        unless ref($type) && $type->isa('Boilerplater::Type');
    my $type_str = $type->to_c;

    if ( $type->is_object ) {
        return "$xs_var = $bp_var == NULL ? newSV(0) : "
            . "XSBind_kobj_to_pobj((kino_Obj*)$bp_var);";
    }
    elsif ( $type->is_primitive ) {
        if ( my $sub = $primitives_to_perl{$type_str} ) {
            return $sub->( $xs_var, $bp_var );
        }
    }
    elsif ( $type->is_composite ) {
        if ( $type_str eq 'void*' ) {
            # Assume that void* is a reference SV -- either a hashref or an
            # arrayref.
            return "$xs_var = newRV_inc( (SV*)($bp_var) );";
        }
    }

    confess("Missing typemap for '$type_str'");
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Perl::TypeMap - Convert between BP and Perl via XS.

=head1 FUNCTIONS

=head2 from_perl

    my $c_code = from_perl( $type, $bp_var, $xs_var, $stack_var );

Return C code which converts from a Perl scalar to a variable of type $type.

Variable declarations must precede the returned code, as from_perl() won't
make any declarations itself.

=over

=item

B<type> - A Boilerplater::Type, which will be used to select the mapping code.

=item

B<bp_var> - The name of the variable being assigned to.

=item

B<xs_var> - The C name of the Perl scalar from which we are extracting a
value.

=item

B<stack_var> - Only required needed when C<type> is Boilerplater::Object
indicating that C<bp_var> is an object of class CharBuf, ByteBuf, or Obj.
When passing strings or other simple types to Boilerplater functions from
Perl, we allow the user to supply simple scalars rather than forcing them to
create Boilerplater objects.  We do this by creating a ZombieCharBuf on the
stack and assigning the string from the Perl scalar to it.  C<stack_var> is
the name of that ZombieCharBuf wrapper.  

=back

=head2 to_perl

    my $c_code = to_perl( $type, $xs_var, $bp_var );

Return C code which converts from a variable of type $type to a Perl scalar.

Variable declarations must precede the returned code, as to_perl() won't make
any declarations itself.

=over

=item

B<type> - A Boilerplater::Type, which will be used to select the mapping code.

=item

B<xs_var> - The C name of the Perl scalar being assigned to.

=item

B<bp_var> - The name of the variable from which we are extracting a value.

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
