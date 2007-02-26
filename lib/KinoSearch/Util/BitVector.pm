use strict;
use warnings;

package KinoSearch::Util::BitVector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        capacity => 0,
    );
}

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
    kino_u32_t capacity = extract_uv(args_hash, SNL("capacity"));

    /* build object */
    RETVAL = kino_BitVec_new(capacity);
}
OUTPUT: RETVAL

kino_bool_t
get(self, num)
    kino_BitVector  *self;
    kino_u32_t       num;
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
        const kino_u32_t num = (kino_u32_t)( SvUV( ST(i) ) );
        Kino_BitVec_Set(self, num);
    }
}


void
clear(self, num)
    kino_BitVector  *self;
    kino_u32_t  num;
PPCODE:
    Kino_BitVec_Clear(self, num);

void
logical_and(self, other)
    kino_BitVector *self;
    kino_BitVector *other;
PPCODE:
    Kino_BitVec_Logical_And(self, other);

kino_u32_t
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
    AV *const out_av  = newAV();
    kino_u32_t count  = Kino_BitVec_Count(self);
    kino_u32_t *array = Kino_BitVec_To_Array(self);
    kino_u32_t *array_copy = array;

    while (count--) {  
        av_push( out_av, newSViv(*array) );
        array++;
    }
    free(array_copy);

    XPUSHs(newRV_noinc( (SV*)out_av ));
    XSRETURN(1);
}

void
_set_or_get(self, ...)
    kino_BitVector *self;
ALIAS:
    get_capacity = 2
    get_bits     = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVuv(self->capacity);
             break;

    case 4:  {
                STRLEN len = ceil(self->capacity / 8.0);
                retval = newSVpv((char*)self->bits, len);
             }
             break;

    END_SET_OR_GET_SWITCH
}

void
_grow(self, size)
    kino_BitVector *self;
    kino_u32_t size;
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

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

