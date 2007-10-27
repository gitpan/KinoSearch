use strict;
use warnings;

package KinoSearch::Store::OutStream;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::OutStream

kino_OutStream*
new(class, file_des)
    const classname_char *class;
    kino_FileDes *file_des;
CODE:
    CHY_UNUSED_VAR(class);
    RETVAL = kino_OutStream_new(file_des);
OUTPUT: RETVAL

void
print(self, ...)
    kino_OutStream *self;
PPCODE:
{
    int i;
    for (i = 1; i < items; i++) {
        STRLEN len;
        char *ptr = SvPV( ST(i), len);
        Kino_OutStream_Write_Bytes(self, ptr, len);
    }
}


chy_u64_t
stell(self)
    kino_OutStream *self;
CODE:
    RETVAL = Kino_OutStream_STell(self);
OUTPUT: RETVAL


chy_u64_t
slength(self)
    kino_OutStream *self;
CODE:
    RETVAL = Kino_OutStream_SLength(self);
OUTPUT: RETVAL


void
sflush(self)
    kino_OutStream *self;
PPCODE:
    Kino_OutStream_SFlush(self);

void
sclose(self)
    kino_OutStream *self;
PPCODE:
    Kino_OutStream_SClose(self);


void
absorb(self, instream)
    kino_OutStream *self;
    kino_InStream  *instream;
PPCODE:
    Kino_OutStream_Absorb(self, instream);

void
_set_or_get(self, ...)
    kino_OutStream *self;
ALIAS:
    get_file_des = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->file_des);
             break;
    
    END_SET_OR_GET_SWITCH
}

=begin comment

    $outstream->lu_write( TEMPLATE, LIST );

Write the items in LIST to the OutStream using the serialization schemes
specified by TEMPLATE.

=end comment
=cut

void
lu_write (self, template_sv, ...)
    kino_OutStream *self;
    SV *template_sv;
PPCODE:
{
    STRLEN      tpt_len;          /* bytelength of template */
    char       *template;         /* ptr to a spot in the template */
    char       *tpt_end;          /* ptr to the end of the template */
    int         repeat_count = 0; /* number of times to repeat sym */
    int         item_count   = 2; /* num elements in @_ processed */
    char        sym = '\0';       /* the current symbol in the template */
    chy_i32_t   aI32;
    chy_u32_t   aU32;
    SV         *aSV;
    char       *string;
    STRLEN      string_len;

    /* require an object, a template, and at least 1 item */
    if (items < 2) {
        CONFESS("lu_write error: too few arguments");
    }

    /* prepare the template and get pointers */
    template = SvPV(template_sv, tpt_len);
    tpt_end  = template + tpt_len;

    /* reject an empty template */
    if (tpt_len == 0) {
        CONFESS("lu_write error: TEMPLATE cannot be empty string");
    }
        
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
                    CONFESS( "Too many ITEMS, not enough TEMPLATE");
                }
                else if (template != tpt_end) {
                    CONFESS("Too much TEMPLATE, not enough ITEMS");
                }
                else { /* success! */
                    break;
                }
            }

            /* derive the current symbol */
            sym = *template++;

            if (template == tpt_end) { /* sym is last char in template */
                repeat_count = 1;
            }
            else {
                char countsym = *template;
                if (countsym >= '0' && countsym <= '9') {
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
        }
        /* sanity check */
        else if (repeat_count < 0) {
            CONFESS("invalid repeat_count: %d", repeat_count);
        }


        switch(sym) {

        case 'a': /* arbitrary binary data */
            aSV  = ST(item_count);
            if (!SvOK(aSV)) {
                CONFESS("Internal error: undef at lu_write 'a'");
            }
            string = SvPV(aSV, string_len);
            if ((STRLEN)repeat_count != string_len) {
                CONFESS("repeat_count != string_len: %d %d", repeat_count, 
                string_len);
            }
            Kino_OutStream_Write_Bytes(self, string, string_len);
            /* trigger next sym */
            repeat_count = 1; 
            break;

        case 'b': /* signed byte */
        case 'B': /* unsigned byte */
            aI32 = SvIV( ST(item_count) );
            Kino_OutStream_Write_Byte(self, (char)(aI32 & 0xff));
            break;

        case 'i': /* signed 32-bit integer */
            aI32 = SvIV( ST(item_count) );
            Kino_OutStream_Write_Int(self, (chy_u32_t)aI32);
            break;
            

        case 'I': /* unsigned 32-bit integer */
            aU32 = SvUV( ST(item_count) );
            Kino_OutStream_Write_Int(self, aU32);
            break;
            
        case 'Q': /* unsigned "64-bit" integer */
            {
                SV *const this_sv = ST(item_count);
                if (SvIOK(this_sv))
                    Kino_OutStream_Write_Long(self, SvUV(this_sv));
                else
                    Kino_OutStream_Write_Long(self, SvNV(this_sv));
            }
            break;
        
        case 'V': /* VInt */
            aU32 = SvUV( ST(item_count) );
            Kino_OutStream_Write_VInt(self, aU32);
            break;

        case 'W': /* VLong */
            {
                SV *const this_sv = ST(item_count);
                if (SvIOK(this_sv))
                    Kino_OutStream_Write_VLong(self, SvUV(this_sv));
                else
                    Kino_OutStream_Write_VLong(self, SvNV(this_sv));
            }
            break;

        case 'T': /* string */
            aSV        = ST(item_count);
            string     = SvPV(aSV, string_len);
            Kino_OutStream_Write_String(self, string, string_len);
            break;

        default: 
            CONFESS("Illegal character in template: %c", sym);
        }

        /* use up one repeat_count and one item from the stack */
        repeat_count--;
        item_count++;
    }
}

__POD__


=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::OutStream - Filehandles for writing invindexes.

=head1 SYNOPSIS

    # isa blessed filehandle

    my $outstream = $folder->open_outstream( $filename );
    $outstream->lu_write( 'V8', @eight_vints );

=head1 DESCRIPTION

The OutStream class abstracts all of KinoSearch's output operations.  It is
akin to a narrowly-implemented, specialized IO::File.

Unlike its counterpart InStream, OutStream cannot be assigned an arbitrary
C<length> or C<offset>.

=head2 Buffering

OutStream objects maintain their own buffers and do not write their contents to
disk on the same schedules as Perl filehandles.

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

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

