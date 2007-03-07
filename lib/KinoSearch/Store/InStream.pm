use strict;
use warnings;

package KinoSearch::Store::InStream;
use base qw( KinoSearch::Util::Obj );
use KinoSearch::Util::ToolSet;

use KinoSearch::Store::FSFileDes;
use KinoSearch::Store::RAMFileDes;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::InStream

kino_InStream*
reopen(self, offset, len)
    kino_InStream *self;
    kino_u64_t offset;
    kino_u64_t len;
CODE:
    RETVAL = Kino_InStream_Reopen(self, offset, len);
OUTPUT: RETVAL

kino_InStream*
new(class, file_des)
    const classname_char *class;
    kino_FileDes *file_des;
CODE:
    KINO_UNUSED_VAR(class);
    RETVAL = kino_InStream_new(file_des);
OUTPUT: RETVAL

void
sseek(self, target)
    kino_InStream *self;
    kino_u64_t     target;
PPCODE:
    Kino_InStream_SSeek(self, target);


kino_u64_t
stell(self)
    kino_InStream *self;
CODE:
    RETVAL = Kino_InStream_STell(self);
OUTPUT: RETVAL

kino_u64_t
slength(self)
    kino_InStream *self;
CODE:
    RETVAL = Kino_InStream_SLength(self);
OUTPUT: RETVAL

void
sclose(self)
    kino_InStream *self;
PPCODE:
    Kino_InStream_SClose(self);

void
_set_or_get(self, ...)
    kino_InStream *self;
ALIAS:
    get_offset   = 2
    get_file_des = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVnv(self->offset);
             break;

    case 4:  retval = kobj_to_pobj(self->file_des);
             break;

    END_SET_OR_GET_SWITCH
}


=begin comment

    @items = $instream->lu_read( TEMPLATE );

Read the items specified by TEMPLATE from the InStream.

=end comment
=cut

void
lu_read (self, template_sv)
    kino_InStream *self;
    SV            *template_sv
PPCODE:
{
    STRLEN    tpt_len;      /* bytelength of template */
    char     *template;     /* ptr to a spot in the template */
    char     *tpt_end;      /* ptr to the end of the template */
    int       repeat_count; /* number of times to repeat sym */
    char      sym = '\0';   /* the current symbol in the template */
    IV        aIV;
    SV       *aSV;
    char      aChar;
    char*     string;
    STRLEN    len;

    /* prepare template string pointers */
    template    = SvPV(template_sv, tpt_len);
    tpt_end     = SvEND(template_sv);

    repeat_count = 0;
    while (1) {
        if (repeat_count == 0) {
            /* fast-forward past space characters */
            while (*template == ' ' && template < tpt_end) {
                template++;
            }

            /* break out of the loop if we've exhausted the template */
            if (template == tpt_end) {
                break;
            }
            
            /* derive the current symbol */
            sym = *template++;

            if (template == tpt_end) { 
                /* sym is last char in template, so process once */
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
        /* thwart potential infinite loop */
        else if (repeat_count < 0) {
            CONFESS( "invalid repeat_count: %d", repeat_count);
        }
        
        switch(sym) {

        case 'a': /* arbitrary binary data */
            len = repeat_count;
            repeat_count = 1;
            aSV = newSV(len + 1);
            SvCUR_set(aSV, len);
            SvPOK_on(aSV);
            *SvEND(aSV) = '\0';
            string = SvPVX(aSV);
            Kino_InStream_Read_Bytes(self, string, len);
            break;

        case 'b': /* signed byte */
        case 'B': /* unsigned byte */
            aChar = Kino_InStream_Read_Byte(self);
            if (sym == 'b') 
                aIV = aChar;
            else
                aIV = (kino_u8_t)aChar;
            aSV = newSViv(aIV);
            break;

        case 'i': /* signed 32-bit integer */
            aSV = newSViv( (kino_i32_t)Kino_InStream_Read_Int(self) );
            break;
            
        case 'I': /* unsigned 32-bit integer */
            aSV = newSVuv( Kino_InStream_Read_Int(self) );
            break;

        case 'Q': /* unsigned "64-bit integer" */
            aSV = newSVnv( Kino_InStream_Read_Long(self) );
            break;

        case 'T': /* string */
            len = Kino_InStream_Read_VInt(self);
            aSV = newSV(len + 1);
            SvCUR_set(aSV, len);
            SvPOK_on(aSV);
            *SvEND(aSV) = '\0';
            string = SvPVX(aSV);
            Kino_InStream_Read_Chars(self, string, 0, len);
            break;

        case 'V': /* VInt */
            aSV = newSVuv( Kino_InStream_Read_VInt(self) );
            break;

        case 'W': /* VLong */
            aSV = newSVnv( Kino_InStream_Read_VLong(self) );
            break;

        default: 
            CONFESS("Invalid type in template: '%c'", sym);
            aSV = Nullsv; /* unreachable; suppress compiler warning */
        }

        /* Put a scalar on the stack, use up one symbol or repeater */
        XPUSHs( sv_2mortal(aSV) );
        repeat_count -= 1;
    }
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::InStream - Filehandles for reading invindexes.

=head1 SYNOPSIS
    
    my $instream  = $folder->open_instream( $filehandle, $offset, $length );
    my @ten_vints = $instream->lu_read('V10');

=head1 DESCRIPTION

The InStream class abstracts out all input operations to KinoSearch.  It is
similar to a filehandle.  

Each InStream maintains its own memory buffer.

For the template used by lu_read, see InStream's companion,
L<OutStream|KinoSearch::Store::OutStream>.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

