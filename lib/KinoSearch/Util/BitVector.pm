package KinoSearch::Util::BitVector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars( capacity => 0, );

sub new {
    my $class = shift;
    verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );
    $class = ref($class) || $class;
    return _new( $class, $args{capacity} );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::BitVector

void
_new(class, capacity)
    char  *class;
    U32    capacity;
PREINIT:
    BitVector *obj;
PPCODE:
    obj   = Kino_BitVec_new(capacity);
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)obj);
    XSRETURN(1);

=for comment
Return true if the bit indcated by $num has been set, false if it hasn't
(regardless of whether $num lies within the bounds of the object's capacity).

=cut

bool
get(obj, num)
    BitVector *obj;
    U32        num;
CODE:
    RETVAL = Kino_BitVec_get(obj, num);
OUTPUT: RETVAL

=for comment
Set the bit at $num to 1.

=cut

void
set(obj, num)
    BitVector *obj;
    U32        num;
PPCODE:
    Kino_BitVec_set(obj, num);

=for comment
Clear the bit at $num (i.e. set it to 0).

=cut

void
clear(obj, num)
    BitVector *obj;
    U32        num;
PPCODE:
    Kino_BitVec_clear(obj, num);

=for comment
Set all the bits bounded by $first and $last, inclusive, to 1.

=cut

void
bulk_set(obj, first, last)
    BitVector *obj;
    U32        first;
    U32        last;
PPCODE:
    Kino_BitVec_bulk_set(obj, first, last);
    
=for comment
Clear all the bits bounded by $first and $last, inclusive.

=cut

void
bulk_clear(obj, first, last)
    BitVector *obj;
    U32        first;
    U32        last;
PPCODE:
    Kino_BitVec_bulk_clear(obj, first, last);

=for comment
Given $num, return either $num (if it is set), the next set bit above it, or
if no such bit exists, undef (from Perl) or a sentinel (0xFFFFFFFF) from C.

=cut
    
SV*
next_set_bit(obj, num)
    BitVector *obj;
    U32        num;
CODE:
    num    = Kino_BitVec_next_set_bit(obj, num);
    RETVAL = num == KINO_BITVEC_SENTINEL ? &PL_sv_undef : newSVuv(num);
OUTPUT: RETVAL

=for comment
Given $num, return $num (if it is clear), or the next clear bit above it.
The highest number that next_clear_bit can return is the object's capacity.

=cut

SV*
next_clear_bit(obj, num)
    BitVector *obj;
    U32        num;
CODE:
    num = Kino_BitVec_next_clear_bit(obj, num);
    RETVAL = num == KINO_BITVEC_SENTINEL ? &PL_sv_undef : newSVuv(num);
OUTPUT: RETVAL

=for comment
Setters and getters.  Two quirks: set_capacity can't adjust capacity
downwards, and set_bits automatically adjusts capacity to the appropriate
multiple of 8.

=cut


SV* 
_set_or_get(obj, ...)
    BitVector *obj;
ALIAS:
    set_capacity = 1
    get_capacity = 2
    set_bits     = 3
    get_bits     = 4
PREINIT:
    STRLEN  len;
    U32     new_capacity;
    char   *new_bits;
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $term_info->set_xxxxxx($val)");

    switch (ix) {

    case 1:  new_capacity = SvUV(ST(1));
             if (new_capacity < obj->capacity) {
                Kino_confess("can't shrink capacity from %d to %d", 
                    obj->capacity, obj->capacity);
             }
             Kino_BitVec_grow(obj, new_capacity);
             /* fall through */
    case 2:  RETVAL = newSVuv(obj->capacity);
             break;

    case 3:  if (obj->bits != NULL) {
                Kino_Safefree(obj->bits);
             }
             new_bits      = SvPV(ST(1), len);
             obj->bits     = (unsigned char*)Kino_savepvn(new_bits, len);
             obj->capacity = len << 3;
             /* fall through */
    case 4:  len = ceil(obj->capacity / 8.0);
             RETVAL = newSVpv((char*)obj->bits, len);
             break;

    default: Kino_confess("Internal error: _set_or_get ix: %d", ix); 
    }
}
OUTPUT: RETVAL


void
DESTROY(obj)
    BitVector *obj;
PPCODE:
    Kino_BitVec_destroy(obj);


__H__

#ifndef H_KINO_BIT_VECTOR
#define H_KINO_BIT_VECTOR 1

#include "limits.h"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilEndianUtils.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilMemManager.h"

#define KINO_BITVEC_SENTINEL 0xFFFFFFFF

typedef struct bitvector {
    U32            capacity;
    unsigned char *bits;
} BitVector;

BitVector* Kino_BitVec_new(U32);
BitVector* Kino_BitVec_clone(BitVector*);
void Kino_BitVec_grow(BitVector*, U32);
void Kino_BitVec_set(BitVector*, U32);
void Kino_BitVec_clear(BitVector*, U32);
void Kino_BitVec_bulk_set(BitVector*, U32, U32);
void Kino_BitVec_bulk_clear(BitVector*, U32, U32);
bool Kino_BitVec_get(BitVector*, U32);
U32  Kino_BitVec_next_set_bit(BitVector*, U32);
U32  Kino_BitVec_next_clear_bit(BitVector*, U32);
void Kino_BitVec_destroy(BitVector*);

#endif /* include guard */

__C__

#include "KinoSearchUtilBitVector.h"

static unsigned char bitmasks[] = { 
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
};

BitVector*
Kino_BitVec_new(U32 capacity) {
    BitVector *obj;
    Kino_New(0, obj, 1, BitVector);
    obj->capacity = 0;
    obj->bits = NULL;
    Kino_BitVec_grow(obj, capacity);
    return obj;
}

BitVector*
Kino_BitVec_clone(BitVector *obj) {
    BitVector *evil_twin;
    U32 byte_size;

    Kino_New(0, evil_twin, 1, BitVector);
    byte_size = ceil(obj->capacity / 8.0);
    evil_twin->bits 
        = (unsigned char*)Kino_savepvn((char*)obj->bits, byte_size);
    evil_twin->capacity = obj->capacity;

    return evil_twin;
}

void
Kino_BitVec_grow(BitVector *obj, U32 capacity) {
    U32 byte_size;
    U32 old_capacity;

    /* derive size in bytes from size in bits */
    byte_size = ceil(capacity / 8.0);

    if (capacity > obj->capacity && obj->bits != NULL) {
        Kino_Renew(obj->bits, byte_size, unsigned char);
        /* zero out all new bits, since Renew doesn't guarantee they're 0 */
        old_capacity = obj->capacity;
        obj->capacity = capacity;
        Kino_BitVec_bulk_clear(obj, old_capacity, capacity - 1);
    }
    else if (obj->bits == NULL) {
        Kino_Newz(0, obj->bits, byte_size, unsigned char);
        obj->capacity = capacity;
    }
}

void 
Kino_BitVec_set(BitVector *obj, U32 num) {
    if (num >= obj->capacity)
        Kino_BitVec_grow(obj, num + 1);
    obj->bits[ (num >> 3) ]  |= bitmasks[num & 0x7];
}

void 
Kino_BitVec_clear(BitVector *obj, U32 num) {
    if (num >= obj->capacity)
        Kino_BitVec_grow(obj, num + 1);

    obj->bits[ (num >> 3) ] &= ~(bitmasks[num & 0x7]);
}


void
Kino_BitVec_bulk_set(BitVector *obj, U32 first, U32 last) {
    unsigned char *ptr;
    U32   num_bytes;

    /* detect range errors */
    if (first > last) {
        Kino_confess("bitvec range error: %d %d %d", first, last, 
            obj->capacity);
    }

    /* grow the bits if necessary */
    if (last >= obj->capacity) {
        Kino_BitVec_grow(obj, last);
    }

    /* set partial bytes */
    while (first % 8 != 0 && first <= last) {
        Kino_BitVec_set(obj, first++);
    }
    while (last % 8 != 0 && last >= first) {
        Kino_BitVec_set(obj, last--);
    }
    Kino_BitVec_set(obj, last);

    /* mass set whole bytes */
    if (last > first) {
        ptr = obj->bits + (first >> 3);
        num_bytes = (last - first) >> 3;
        memset(ptr, 0xff, num_bytes);
    }
}

void
Kino_BitVec_bulk_clear(BitVector *obj, U32 first, U32 last) {
    unsigned char *ptr;
    U32   num_bytes;

    /* detect range errors */
    if (first > last) {
        Kino_confess("bitvec range error: %d %d %d", first, last, 
            obj->capacity);
    }

    /* grow the bits if necessary */
    if (last >= obj->capacity) {
        Kino_BitVec_grow(obj, last);
    }

    /* clear partial bytes */
    while (first % 8 != 0 && first <= last) {
        Kino_BitVec_clear(obj, first++);
    }
    while (last % 8 != 0 && last >= first) {
        Kino_BitVec_clear(obj, last--);
    }
    Kino_BitVec_clear(obj, last);

    /* mass clear whole bytes */
    if (last > first) {
        ptr = obj->bits + (first >> 3);
        num_bytes = (last - first) >> 3;
        memset(ptr, 0, num_bytes);
    }
}

bool
Kino_BitVec_get(BitVector *obj, U32 num) {
    if (num >= obj->capacity) return 0;
    return (obj->bits[ (num >> 3) ] & bitmasks[num & 0x7]) != 0;
}

U32
Kino_BitVec_next_set_bit(BitVector *obj, U32 num) {
    U32   outval;
    unsigned char *bits_ptr;
    unsigned char *end_ptr;
    int i;
    U32 byte_size;

    if (num >= obj->capacity) {
        return KINO_BITVEC_SENTINEL;
    }

    outval = KINO_BITVEC_SENTINEL;

    bits_ptr  = obj->bits + (num >> 3) ;
    byte_size = ceil(obj->capacity / 8.0);
    end_ptr   = obj->bits + byte_size;

    while (outval == KINO_BITVEC_SENTINEL) {
        if (*bits_ptr != 0) {
            /* check each num in represented in this byte */
            outval = (bits_ptr - obj->bits) * 8;
            for (i = 0; i < 8; i++) {
                if (Kino_BitVec_get(obj, outval) == 1) {
                    if (outval < obj->capacity && outval >= num) {
                        return outval;
                    }
                }
                outval++;
            }
            /* nothing valid, so reset the sentinel */
            outval = KINO_BITVEC_SENTINEL;
        }
        if (++bits_ptr >= end_ptr)
            break;
    }
    /* nothing valid, so return a sentinel */
    return KINO_BITVEC_SENTINEL;
}

U32
Kino_BitVec_next_clear_bit(BitVector *obj, U32 num) {
    U32   outval;
    unsigned char *bits_ptr;
    unsigned char *end_ptr;
    int i;

    if (num >= obj->capacity) {
        return num;
    }

    outval = KINO_BITVEC_SENTINEL;

    bits_ptr = obj->bits + (num >> 3) ;
    end_ptr  = obj->bits + (obj->capacity >> 3);

    while (outval == KINO_BITVEC_SENTINEL) {
        if (*bits_ptr != 0xFF) {
            /* check each num in represented in this byte */
            outval = (bits_ptr - obj->bits) * 8;
            for (i = 0; i < 8; i++) {
                if (Kino_BitVec_get(obj, outval) == 0) {
                    if (outval < obj->capacity && outval >= num) {
                        return outval;
                    }
                }
                outval++;
            }
            /* nothing valid, so reset the sentinel */
            outval = KINO_BITVEC_SENTINEL;
        }
        if (++bits_ptr >= end_ptr)
            break;
    }
    /* didn't find clear bits in the set, so return 1 larger than the max */
    return obj->capacity;
}

void
Kino_BitVec_destroy(BitVector* obj) {
    Kino_Safefree(obj->bits);
    Kino_Safefree(obj);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::BitVector - a set of bits

=head1 DESCRIPTION

A vector of bits, which grows as needed.  The implementation is designed to
resemble both org.apache.lucene.util.BitVector and java.util.BitSet.  
Accessible from both C and Perl.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=end devdocs
=cut

