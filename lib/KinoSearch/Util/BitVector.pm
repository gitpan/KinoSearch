use strict;
use warnings;

package KinoSearch::Util::BitVector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    capacity => 0,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::BitVector

kino_BitVector*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::BitVector::instance_vars");
    chy_u32_t capacity = extract_uv(args_hash, SNL("capacity"));

    /* build object */
    RETVAL = kino_BitVec_new(capacity);
}
OUTPUT: RETVAL

chy_bool_t
get(self, num)
    kino_BitVector  *self;
    chy_u32_t        num;
CODE:
    RETVAL = Kino_BitVec_Get(self, num);
OUTPUT: RETVAL


void
set(self, ...)
    kino_BitVector *self;
PPCODE:
{
    I32 i;
    for (i = 1; i < items; i++) {
        const chy_u32_t num = (chy_u32_t)( SvUV( ST(i) ) );
        Kino_BitVec_Set(self, num);
    }
}


void
clear(self, num)
    kino_BitVector *self;
    chy_u32_t       num;
PPCODE:
    Kino_BitVec_Clear(self, num);

void
flip(self, num)
    kino_BitVector *self;
    chy_u32_t       num;
PPCODE:
    Kino_BitVec_Flip(self, num);

void
flip_range(self, from_tick, to_tick)
    kino_BitVector *self;
    chy_u32_t       from_tick;
    chy_u32_t       to_tick;
PPCODE:
    Kino_BitVec_Flip_Range(self, from_tick, to_tick);

void
AND(self, other)
    kino_BitVector *self;
    kino_BitVector *other;
PPCODE:
    Kino_BitVec_And(self, other);

void
OR(self, other)
    kino_BitVector *self;
    kino_BitVector *other;
PPCODE:
    Kino_BitVec_Or(self, other);

void
XOR(self, other)
    kino_BitVector *self;
    kino_BitVector *other;
PPCODE:
    Kino_BitVec_Xor(self, other);

void
AND_NOT(self, other)
    kino_BitVector *self;
    kino_BitVector *other;
PPCODE:
    Kino_BitVec_And_Not(self, other);

chy_u32_t
count(self)
    kino_BitVector *self;
CODE:
    RETVAL = Kino_BitVec_Count(self);
OUTPUT: RETVAL

void
to_arrayref(self)
    kino_BitVector *self;
PPCODE:
{
    AV  *const out_av      = newAV();
    chy_u32_t  count       = Kino_BitVec_Count(self);
    chy_u32_t *array       = Kino_BitVec_To_Array(self);
    chy_u32_t *array_copy  = array;

    while (count--) {  
        av_push( out_av, newSViv(*array) );
        array++;
    }
    free(array_copy);

    XPUSHs( sv_2mortal(newRV_noinc( (SV*)out_av )) );
    XSRETURN(1);
}

void
_set_or_get(self, ...)
    kino_BitVector *self;
ALIAS:
    get_cap      = 2 
    get_bits     = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVuv(self->cap);
             break;

    case 4:  {
                STRLEN len = ceil(self->cap / 8.0);
                retval = newSVpv((char*)self->bits, len);
             }
             break;

    END_SET_OR_GET_SWITCH
}

void
_grow(self, size)
    kino_BitVector *self;
    chy_u32_t size;
PPCODE:
    Kino_BitVec_Grow(self, size);


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::BitVector - A set of bits.

=head1 DESCRIPTION

A vector of bits.  Accessible from both C and Perl.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

