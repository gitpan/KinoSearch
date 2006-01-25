package KinoSearch::Index::TermBuffer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args
    finfos => undef,
);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my %args = ( %instance_vars, @_ );
    verify_args( \%instance_vars, %args );
    my $self = _new( $class, $args{finfos}, $args{finfos}->get_fnum_map );
    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermBuffer

void
_new(class, finfos_sv, fnum_map_sv) 
    char       *class;
    SV         *finfos_sv;
    SV         *fnum_map_sv;
PREINIT:
    TermBuffer *term_buf;
    char       *ptr;
    STRLEN      len;
PPCODE:
{
    Kino_New(0, term_buf, 1, TermBuffer);
    SvREFCNT_inc(finfos_sv);
    term_buf->finfos = finfos_sv;

    /* reset the TermBuffer */
    term_buf->termstring = NULL;
    Kino_TermBuf_reset(term_buf);

    /* copy the fnum_map, derive max_field_num */
    ptr                     = SvPV(fnum_map_sv, len);
    term_buf->fnum_map      = Kino_savepvn(ptr, len);
    term_buf->max_field_num = (len / KINO_FIELD_NUM_LEN) - 1;
    
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)term_buf);
    XSRETURN(1);
}

void
DESTROY(term_buf)
    TermBuffer *term_buf;
PPCODE:
    Kino_TermBuf_destroy(term_buf);


void
_set_text_len(term_buf, new_len)
    TermBuffer *term_buf;
    UV          new_len;
PPCODE:
    Kino_TermBuf_set_text_len(term_buf, new_len);
    


__H__

#ifndef H_KINOSEARCH_INDEX_TERM_BUFFER
#define H_KINOSEARCH_INDEX_TERM_BUFFER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilMemManager.h"
#include "KinoSearchIndexTerm.h"

typedef struct termbuffer {
    SV      *finfos;
    char    *termstring;
    STRLEN   text_len;
    STRLEN   capacity;
    char    *fnum_map;
    U32      max_field_num;
} TermBuffer;

void Kino_TermBuf_read(TermBuffer*, PerlIO*);
void Kino_TermBuf_destroy(TermBuffer*);
void Kino_TermBuf_reset(TermBuffer*);
void Kino_TermBuf_set_text_len(TermBuffer*, STRLEN);

#endif /* include guard */

__C__

#include "KinoSearchIndexTermBuffer.h"

/* Decode the next term in a term dictionary file (.tii, .tis), but don't turn
 * it into a full-fledged Term object. */
void
Kino_TermBuf_read(TermBuffer *term_buf, PerlIO *fh) {
    I32 text_overlap;
    STRLEN finish_chars_len;
    STRLEN total_text_len;
    U32 field_num;

    /* read bytes which are shared between the last term text and this */
    text_overlap     = Kino_IO_read_vint(fh);
    finish_chars_len = Kino_IO_read_vint(fh);
    total_text_len   = text_overlap + finish_chars_len;
    Kino_TermBuf_set_text_len(term_buf, total_text_len);
    Kino_IO_read_chars(fh, term_buf->termstring, 
        (text_overlap + KINO_FIELD_NUM_LEN),
        finish_chars_len);

    /* read orig field num -- not the same as the final; see FieldInfos */
    field_num = Kino_IO_read_vint(fh);
    if (field_num > term_buf->max_field_num && field_num != -1)
        Kino_confess("Internal error: field_num %d > max_field_num %d",
            field_num, term_buf->max_field_num);

    if (field_num == -1) {
        term_buf->termstring[0] = 0xff;     
        term_buf->termstring[1] = 0xff;
    }
    /* assign the KinoSearch-compatible field num from the map */
    else {
        Copy( (term_buf->fnum_map + 2*field_num), 
               term_buf->termstring, 2, char);
    }

}

/* Set the TermBuffer object to a sentinel state, indicating that it does not
 * hold a valid Term */
void
Kino_TermBuf_reset(TermBuffer *term_buf) {
    if (term_buf->termstring != NULL) {
        Kino_Safefree(term_buf->termstring);
    }
    term_buf->termstring = NULL;
    term_buf->text_len   = 0;
    term_buf->capacity   = 0;
}

/* Set the length of the term text, and ensure that there's enough memory
 * allocated to hold term text that size. */
void 
Kino_TermBuf_set_text_len(TermBuffer *term_buf, STRLEN new_len) {
    term_buf->text_len = new_len;
    
    /* bail if the buffer's already at least as big as required */
    if (term_buf->capacity >= new_len + KINO_FIELD_NUM_LEN) {
        return;
    }
    else {
        STRLEN amount_to_malloc;

        term_buf->capacity = new_len + KINO_FIELD_NUM_LEN;
        amount_to_malloc   = term_buf->capacity + 1;
        if (term_buf->termstring == NULL) {
            Kino_New(0, term_buf->termstring, amount_to_malloc, char);
            Copy("\0\0", term_buf->termstring, 2, char);
        }
        else {
            Kino_Renew(term_buf->termstring, amount_to_malloc, char);
        }
        term_buf->termstring[ term_buf->capacity ] = '\0';
    }
}

void 
Kino_TermBuf_destroy(TermBuffer *term_buf) {
    Kino_TermBuf_reset(term_buf);
    Kino_Safefree(term_buf->fnum_map);
    SvREFCNT_dec(term_buf->finfos);
    Kino_Safefree(term_buf);
}

__POD__


=begin devdocs

=head1 NAME

KinoSearch::Index::TermBuffer - decode a term dictionary one Term at a time

=head1 DESCRIPTION

A TermBuffer iterates through a term dictionary, holding one current term in a
buffer.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=end devdocs
=cut
