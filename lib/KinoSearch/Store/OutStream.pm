package KinoSearch::Store::OutStream;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;

# Constructor - takes one arg: a filehandle.
sub new {
    my ( $class, $fh ) = @_;
    bless $fh, ref($class) || $class;
}

# Close the outstream.
sub close { CORE::close $_[0] }

# Get a filepointer.
sub tell { CORE::tell $_[0] }

# Seek outstream to a position relative to the start of the file.
sub seek { CORE::seek( $_[0], $_[1], 0 ) }

# Return the current length of the file in bytes.
sub length {
    my $self     = shift;
    my $bookmark = CORE::tell $self;
    CORE::seek( $self, 0, 2 );
    my $len = CORE::tell $self;
    CORE::seek( $self, $bookmark, 0 );
    return $len;
}

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::OutStream

=begin comment

    $outstream->lu_write( TEMPLATE, LIST );

Write the items in LIST to the OutStream using the serialization schemes
specified by TEMPLATE.

=end comment
=cut

void
lu_write (fh, template_sv, ...)
    PerlIO  *fh;
    SV      *template_sv;
PREINIT:
    STRLEN   tpt_len;      /* bytelength of template */
    char    *template;     /* ptr to a spot in the template */
    char    *tpt_end;      /* ptr to the end of the template */
    int      repeat_count; /* number of times to repeat sym */
    int      item_count;   /* current place in @_ */
    char     sym;          /* the current symbol in the template */
    char     countsym;     /* used when calculating repeat counts */
    I32      aI32;
    U32      aU32;
    double   aDouble;
    SV      *aSV;
    char    *string;
    STRLEN   string_len;
PPCODE:
{
    /* require an object, a template, and at least 1 item */
    if (items < 2) {
        Kino_confess("Kino_IO error: too few arguments");
    }

    /* prepare the template and get pointers */
    tpt_len  = SvCUR(template_sv);
    template = SvPV(template_sv, tpt_len);
    tpt_end  = template + tpt_len;

    /* reject an empty template */
    if (tpt_len == 0) {
        Kino_confess("Kino_IO error: TEMPLATE cannot be empty string");
    }
        
    /* init counters */
    repeat_count = 0;
    item_count   = 2;

    while (1) {
        /* only process template if we're not in the midst of a repeat */
        if (repeat_count == 0) {
            /* fast-forward past space characters */
            while (*template == ' ' && template < tpt_end) {
                template++;
            }

            /* if we're done, return or throw error */
            if (template == tpt_end || item_count == items) {
                if (item_count != items) {
                    Kino_confess(
                      "Kino_IO error: Too many ITEMS, not enough TEMPLATE");
                }
                else if (template != tpt_end) {
                    Kino_confess(
                      "Kino_IO error: Too much TEMPLATE, not enough ITEMS");
                }
                else { /* success! */
                    break;
                }
            }

            /* derive the current symbol and a possible digit repeat sym */
            sym      = *template++;
            countsym = *template;

            if (template == tpt_end) { /* sym is last char in template */
                repeat_count = 1;
            }
            else if (countsym >= '0' && countsym <= '9') {
                /* calculate numerical repeat count */
                repeat_count = countsym - KINO_NUM_CHAR_OFFSET;
                countsym = *(++template);
                while (  template <= tpt_end 
                      && countsym >= '0' 
                      && countsym <= '9'
                ) {
                    repeat_count = (repeat_count * 10) 
                        + (countsym - KINO_NUM_CHAR_OFFSET);
                    countsym = *(++template);
                }
            }
            else { /* no numeric repeat count, so process sym only once */
                repeat_count = 1;
            }
        }


        switch(sym) {

        case 'a': /* arbitrary binary data */
            aSV  = ST(item_count);
            if (!SvOK(aSV)) {
                Kino_confess("Internal error: undef at lu_write 'a'");
            }
            string_len = SvCUR(aSV);
            string     = SvPV(aSV, string_len);
            if (repeat_count != string_len) {
                Kino_confess(
                    "Kino_IO error: repeat_count != string_len: %d %d", 
                    repeat_count, string_len);
            }
            Kino_IO_write_bytes(fh, string, string_len);
            /* trigger next sym */
            repeat_count = 1; 
            break;

        case 'b': /* signed byte */
        case 'B': /* unsigned byte */
            aI32 = SvIV( ST(item_count) );
            Kino_IO_write_byte(fh, (char)(aI32 & 0xff));
            break;

        case 'i': /* signed 32-bit integer */
            aI32 = SvIV( ST(item_count) );
            Kino_IO_write_int(fh, (U32)aI32);
            break;
            

        case 'I': /* unsigned 32-bit integer */
            aU32 = SvUV( ST(item_count) );
            Kino_IO_write_int(fh, aU32);
            break;
            
        case 'Q': /* unsigned "64-bit" integer */
            aDouble = SvNV( ST(item_count) );
            Kino_IO_write_long(fh, aDouble);
            break;
        
        case 'V': /* VInt */
            aU32 = SvUV( ST(item_count) );
            Kino_IO_write_vint(fh, aU32);
            break;

        case 'W': /* VLong */
            aDouble = SvNV( ST(item_count) );
            Kino_IO_write_vlong(fh, aDouble);
            break;

        case 'T': /* string */
            aSV        = ST(item_count);
            string_len = SvCUR(aSV);
            string     = SvPV(aSV, string_len);
            Kino_IO_write_string(fh, string, string_len);
            break;

        default: 
            Kino_confess("Illegal character in template: %c", sym);
        }

        /* use up one repeat_count and one item from the stack */
        repeat_count--;
        item_count++;
    }
}

__H__


#ifndef H_KINOIO
#define H_KINOIO 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchStoreInStream.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilEndianUtils.h"

void Kino_IO_write_byte   (PerlIO*, char);
void Kino_IO_write_int    (PerlIO*, U32);
void Kino_IO_write_long   (PerlIO*, double);
void Kino_IO_write_vint   (PerlIO*, U32);
int  Kino_IO_encode_vint  (U32, char*);
void Kino_IO_write_vlong  (PerlIO*, double);
void Kino_IO_write_string (PerlIO*, char*, STRLEN);
void Kino_IO_write_bytes  (PerlIO*, char*, STRLEN);

#endif /* include guard */


__C__

#include "KinoSearchStoreOutStream.h"
       
void
Kino_IO_write_byte(PerlIO *fh, char aChar) {
    int check_val;

    check_val = PerlIO_write(fh, &aChar, 1);
    if (check_val != 1)
        Kino_confess("Kino_IO_write_byte error: %d", check_val);
}

void 
Kino_IO_write_int(PerlIO *fh, U32 aU32) {
    unsigned char buf[4];
    int           check_val;

    Kino_encode_bigend_U32(aU32, buf);
    check_val = PerlIO_write(fh, buf, 4);
    if (check_val != 4)
        Kino_confess("Kino_IO_write_int error: %d", check_val);
}

void
Kino_IO_write_long(PerlIO *fh, double aDouble) {
    unsigned char buf[8];
    U32 aU32;
    int check_val;

    /* derive the upper 4 bytes by truncating a quotient */
    aU32 = floor( ldexp( aDouble, -32 ) );
    Kino_encode_bigend_U32(aU32, buf);
    
    /* derive the lower 4 bytes by taking a modulus against 2**32 */
    aU32 = fmod(aDouble, (pow(2.0, 32.0)));
    Kino_encode_bigend_U32(aU32, &buf[4]);

    /* print encoded Long to the output handle */
    check_val = PerlIO_write(fh, buf, 8);
    if (check_val != 8)
        Kino_confess("Kino_IO_write_long error: %d", check_val);
}

void
Kino_IO_write_vint(PerlIO *fh, U32 aU32) {
    char buf[5];
    int check_val;
    int num_bytes;

    num_bytes = Kino_IO_encode_vint(aU32, buf);
    
    /* print encoded VInt to the output handle */
    check_val = PerlIO_write(fh, buf, num_bytes);
    if (check_val != num_bytes)
        Kino_confess("Kino_IO_write_vint error: %d %d", check_val, num_bytes);
}

int
Kino_IO_encode_vint(U32 aU32, char *buf) {
    int num_bytes = 0;

    while ((aU32 & ~0x7f) != 0) {
        buf[num_bytes++] = ( (aU32 & 0x7f) | 0x80 );
        aU32 >>= 7;
    }
    buf[num_bytes++] = aU32 & 0x7f;

    return num_bytes;
}

void
Kino_IO_write_vlong(PerlIO *fh, double aDouble) {
    unsigned char buf[10];
    int check_val;
    int num_bytes = 0;
    U32 aU32;

    while (aDouble > 127.0) {
        /* take modulus of num against 128 */
        aU32 = fmod(aDouble, 128);
        buf[num_bytes++] = ( (aU32 & 0x7f) | 0x80 );
        /* right shift for floating point! */
        aDouble = floor( ldexp( aDouble, -7 ) );
    }
    buf[num_bytes++] = aDouble;
    
    check_val = PerlIO_write(fh, buf, num_bytes);
    if (check_val != num_bytes)
        Kino_confess("Kino_IO_write_vlong error: %d, %d", 
            check_val, num_bytes);
}

void
Kino_IO_write_string(PerlIO *fh, char *string, STRLEN len) {
    U32 aU32;

    aU32 = len;
    Kino_IO_write_vint(fh, aU32);
    Kino_IO_write_bytes(fh, string, len);
}
void
Kino_IO_write_bytes(PerlIO *fh, char *string, STRLEN len) {
    int check_val;

    check_val = PerlIO_write(fh, string, len);
    if (check_val != len)
        Kino_confess("Kino_IO_write_bytes error: %d", check_val);
 }


__POD__


=begin devdocs

=head1 NAME

KinoSearch::Store::OutStream - filehandles for writing invindexes

=head1 SYNOPSIS

    # isa blessed filehandle

    my $outstream = $invindex->open_outstream( $filename );
    $outstream->lu_write( 'V8', @eight_vints );

=head1 DESCRIPTION

The OutStream class abstracts all of KinoSearch's output operations.  It is
akin to a narrowly-implemented, specialized IO::File.

Unlike its counterpart InStream, OutStream cannot be assigned an arbitrary
C<length> or C<offset>.

=head2 lu_write / lu_read template

lu_write and it's opposite number, InStream's lu_read, provide a
pack/unpack-style interface for handling primitive data types required by the
Lucene index file format.  The most notable of these specialized data types is
the VInt, or Variable Integer, which is similar to the BER compressed integer
(pack template 'w').

All fixed-width integer formats are stored in big-endian order (high-byte
first).  Signed integers use twos-complement encoding.  The maximum allowable
value both Long and VLong is 2**52 because it is stored inside the NV (double)
storage pocket of a perl Scalar, which has a 53-bit mantissa.
 
    a   Arbitrary binary data, copied to/from the scalar's PV (string)

    b   8-bit  integer, signed
    B   8-bit  integer, unsigned

    i   32-bit integer, signed
    I   32-bit integer, unsigned

    Q   64-bit integer, unsigned                (max value 2**52)

    V   VInt   variable-width integer, unsigned (max value 2**32)
    W   VLong  variable-width integer, unsigned (max value 2**52)

    T   Lucene string, which is a VInt indicating the length in bytes 
        followed by the string.  The string must be valid UTF-8.

Numeric repeat counts are supported:

    $outstream->lu_write( 'V2 T', 0, 1, "a string" );
     
Other features of pack/unpack such as parentheses, infinite repeats via '*',
and slash notation are not.  A numeric repeat count following 'a' indicates
how many bytes to read, while a count following any other symbol indicates how
many scalars of that type to return.

    ( $three_byte_string, @eight_vints ) = $instream->lu_read('a3V8');

The behavior of lu_read and lu_write is much more strict with regards to a
mismatch between TEMPLATE and LIST than pack/unpack, which are fairly
forgiving in what they will accept.  lu_read will confess() if it cannot read
all the items specified by TEMPLATE from the InStream, and lu_write will
confess() if the number of items in LIST does not match the expression in
TEMPLATE.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.06.

=end devdocs
=cut

