package KinoSearch::Index::SegTermDocs;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermDocs );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        reader => undef,
    );
}
our %instance_vars;

sub new {
    my $self = shift->SUPER::new;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    _init_child($self);

    # dupe some stuff from the parent reader.
    $self->_set_reader( $args{reader} );
    $self->_set_freq_stream( $args{reader}->get_freq_stream()->clone_stream );
    $self->_set_prox_stream( $args{reader}->get_prox_stream()->clone_stream );
    $self->_set_deldocs( $args{reader}->get_deldocs );

    return $self;
}

sub seek {
    my ( $self, $term ) = @_;
    my $tinfo =
        defined $term
        ? $self->_get_reader()->fetch_term_info($term)
        : undef;
    $self->seek_tinfo($tinfo);
}

sub close {
    my $self = shift;
    $self->_get_freq_stream()->close;
    $self->_get_prox_stream()->close;
}

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::SegTermDocs

void
_init_child(term_docs)
    TermDocs *term_docs;
PPCODE:
    Kino_SegTermDocs_init_child(term_docs);

SV*
_set_or_get(term_docs, ...)
    TermDocs *term_docs;
ALIAS:
    _set_count         = 1
    _get_count         = 2
    _set_freq_stream   = 3
    _get_freq_stream   = 4
    _set_prox_stream   = 5
    _get_prox_stream   = 6
    _set_deldocs       = 7
    _get_deldocs       = 8 
    _set_reader        = 9 
    _get_reader        = 10
    set_read_positions = 11
    get_read_positions = 12
CODE:
{
    SegTermDocsChild *child = (SegTermDocsChild*)term_docs->child;

    KINO_START_SET_OR_GET_SWITCH

    case 1:  child->count = SvUV(ST(1));
             /* fall through */
    case 2:  RETVAL = newSVuv(child->count);
             break;

    case 3:  SvREFCNT_dec(child->freq_stream_sv);
             child->freq_stream_sv = newSVsv( ST(1) );
             Kino_extract_struct( child->freq_stream_sv, child->freq_stream, 
                InStream*, "KinoSearch::Store::InStream");
             /* fall through */
    case 4:  RETVAL = newSVsv(child->freq_stream_sv);
             break;

    case 5:  SvREFCNT_dec(child->prox_stream_sv);
             child->prox_stream_sv = newSVsv( ST(1) );
             Kino_extract_struct( child->prox_stream_sv, child->prox_stream, 
                InStream*, "KinoSearch::Store::InStream");
             /* fall through */
    case 6:  RETVAL = newSVsv(child->prox_stream_sv);
             break;

    case 7:  SvREFCNT_dec(child->deldocs_sv);
             child->deldocs_sv = newSVsv( ST(1) );
             Kino_extract_struct( child->deldocs_sv, child->deldocs, 
                BitVector*, "KinoSearch::Index::DelDocs" );
             /* fall through */
    case 8:  RETVAL = newSVsv(child->deldocs_sv);
             break;

    case 9:  SvREFCNT_dec(child->reader_sv);
             if (!sv_derived_from( ST(1), "KinoSearch::Index::IndexReader") )
                Kino_confess("not a KinoSearch::Index::IndexReader");
             child->reader_sv = newSVsv( ST(1) );
             /* fall through */
    case 10: RETVAL = newSVsv(child->reader_sv);
             break;

    case 11: term_docs->next = SvTRUE( ST(1) ) 
                ? Kino_SegTermDocs_next_with_positions
                : Kino_SegTermDocs_next;
             /* fall through */
    case 12: RETVAL = term_docs->next == Kino_SegTermDocs_next_with_positions 
                ? newSViv(1) : newSViv(0);
             break;

    KINO_END_SET_OR_GET_SWITCH
}
OUTPUT: RETVAL

__H__

#ifndef H_KINO_SEG_TERM_DOCS
#define H_KINO_SEG_TERM_DOCS 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilBitVector.h"
#include "KinoSearchIndexTermDocs.h"
#include "KinoSearchIndexTermInfo.h"
#include "KinoSearchStoreInStream.h"
#include "KinoSearchUtilMemManager.h"

typedef struct segtermdocschild {
    U32        count;
    U32        doc_freq;
    U32        doc;
    U32        freq;
    SV        *positions;
    InStream  *freq_stream;
    InStream  *prox_stream;
    BitVector *deldocs;
    SV        *freq_stream_sv;
    SV        *prox_stream_sv;
    SV        *deldocs_sv;
    SV        *reader_sv;
} SegTermDocsChild;

void Kino_SegTermDocs_init_child(TermDocs*);
void Kino_SegTermDocs_set_doc_freq(TermDocs*, U32);
U32  Kino_SegTermDocs_get_doc_freq(TermDocs*);
U32  Kino_SegTermDocs_get_doc(TermDocs*);
U32  Kino_SegTermDocs_get_freq(TermDocs*);
SV*  Kino_SegTermDocs_get_positions(TermDocs*);
U32  Kino_SegTermDocs_bulk_read(TermDocs*, SV*, SV*, U32);
void Kino_SegTermDocs_seek_tinfo(TermDocs*, TermInfo*);
bool Kino_SegTermDocs_next(TermDocs*);
bool Kino_SegTermDocs_next_with_positions(TermDocs*);
void Kino_SegTermDocs_destroy(TermDocs*);

#endif /* include guard */

__C__

#include "KinoSearchIndexSegTermDocs.h"

void
Kino_SegTermDocs_init_child(TermDocs *term_docs) {
    SegTermDocsChild *child;

    Kino_New(1, child, 1, SegTermDocsChild);
    term_docs->child = child;

    child->doc_freq = KINO_TERM_DOCS_SENTINEL;
    child->doc      = KINO_TERM_DOCS_SENTINEL;
    child->freq     = KINO_TERM_DOCS_SENTINEL;

    /* child->positions starts life as an empty string */
    child->positions = newSV(1);
    SvCUR_set(child->positions, 0);
    SvPOK_on(child->positions);

    term_docs->set_doc_freq  = Kino_SegTermDocs_set_doc_freq;
    term_docs->get_doc_freq  = Kino_SegTermDocs_get_doc_freq;
    term_docs->get_doc       = Kino_SegTermDocs_get_doc;
    term_docs->get_freq      = Kino_SegTermDocs_get_freq;
    term_docs->get_positions = Kino_SegTermDocs_get_positions;
    term_docs->bulk_read     = Kino_SegTermDocs_bulk_read;
    term_docs->seek_tinfo    = Kino_SegTermDocs_seek_tinfo;
    term_docs->next          = Kino_SegTermDocs_next;
    term_docs->destroy       = Kino_SegTermDocs_destroy;

    child->freq_stream_sv   = &PL_sv_undef;
    child->prox_stream_sv   = &PL_sv_undef;
    child->deldocs_sv       = &PL_sv_undef;
    child->reader_sv        = &PL_sv_undef;
    child->count            = 0;
}

void
Kino_SegTermDocs_set_doc_freq(TermDocs *term_docs, U32 doc_freq) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;
    child->doc_freq = doc_freq;
}

U32
Kino_SegTermDocs_get_doc_freq(TermDocs *term_docs) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;
    return child->doc_freq;
}

U32
Kino_SegTermDocs_get_doc(TermDocs *term_docs) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;
    return child->doc;
}


U32
Kino_SegTermDocs_get_freq(TermDocs *term_docs) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;
    return child->freq;
}

SV*
Kino_SegTermDocs_get_positions(TermDocs *term_docs) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;
    return child->positions;
}

U32 
Kino_SegTermDocs_bulk_read(TermDocs *term_docs, SV* doc_nums_sv, 
                           SV* freqs_sv, U32 num_wanted) {
    SegTermDocsChild *child;
    InStream         *freq_stream;
    U32               doc_code;
    U32              *doc_nums;
    U32              *freqs;
    STRLEN            len;
    U32               num_got = 0;

    /* local copies */
    child       = (SegTermDocsChild*)term_docs->child;
    freq_stream = child->freq_stream;

    /* allocate space in supplied SVs and make them POK, if necessary */ 
    len = num_wanted * sizeof(U32);
    SvUPGRADE(doc_nums_sv, SVt_PV);
    SvUPGRADE(freqs_sv,    SVt_PV);
    SvPOK_on(doc_nums_sv);
    SvPOK_on(freqs_sv);
    doc_nums = (U32*)SvGROW(doc_nums_sv, len + 1);
    freqs    = (U32*)SvGROW(freqs_sv,    len + 1);

    while (child->count < child->doc_freq && num_got < num_wanted) {
        /* manually inlined call to term_docs->next */ 
        child->count++;
        doc_code = freq_stream->read_vint(freq_stream);;
        child->doc  += doc_code >> 1;
        if (doc_code & 1)
            child->freq = 1;
        else
            child->freq = freq_stream->read_vint(freq_stream);

        /* if the doc isn't deleted... */
        if ( !Kino_BitVec_get(child->deldocs, child->doc) ) {
            /* ... append to results */
            *doc_nums++ = child->doc;
            *freqs++    = child->freq;
            num_got++;
        }
    }

    /* set the string end to the end of the U32 array */
    SvCUR_set(doc_nums_sv, (num_got * sizeof(U32)));
    SvCUR_set(freqs_sv,    (num_got * sizeof(U32)));

    return num_got;
}

bool
Kino_SegTermDocs_next_with_positions(TermDocs *term_docs) {
    U32               doc_code;
    U32               position = 0; 
    U32              *positions;
    U32              *positions_end;
    STRLEN            len;
    SegTermDocsChild *child;
    InStream         *freq_stream;
    InStream         *prox_stream;
    
    /* local copies */
    child       = (SegTermDocsChild*)term_docs->child;
    freq_stream = child->freq_stream;
    prox_stream = child->prox_stream;
    
    while (1) {
        /* bail if we're out of docs */
        if (child->count == child->doc_freq) {
            return 0;
        }

        /* decode delta doc */
        doc_code = freq_stream->read_vint(freq_stream);
        child->doc  += doc_code >> 1;

        /* if the stored num was odd, the freq is 1 */ 
        if (doc_code & 1) {
            child->freq = 1;
        }
        /* otherwise, freq was stored as a VInt. */
        else {
            child->freq = freq_stream->read_vint(freq_stream);
        } 

        child->count++;
        
        /* store positions */
        len = child->freq * sizeof(U32);
        SvGROW( child->positions, len );
        SvCUR_set(child->positions, len);
        positions = (U32*)SvPVX(child->positions);
        positions_end = (U32*)SvEND(child->positions);
        while (positions < positions_end) {
            position += prox_stream->read_vint(prox_stream);
            *positions++ = position;
        }
        
        /* if the doc isn't deleted... success! */
        if (!Kino_BitVec_get(child->deldocs, child->doc))
            break;
    }
    return 1;
}

void
Kino_SegTermDocs_seek_tinfo(TermDocs *term_docs, TermInfo *tinfo) {
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;

    child->count = 0;

    if (tinfo == NULL) {
        child->doc_freq = 0;
    }
    else {
        child->doc      = 0;
        child->freq     = 0;
        child->doc_freq = tinfo->doc_freq;
        child->freq_stream->seek( child->freq_stream, tinfo->frq_fileptr );
        child->prox_stream->seek( child->prox_stream, tinfo->prx_fileptr );
    }
}

bool
Kino_SegTermDocs_next(TermDocs *term_docs) {
    U32               doc_code;
    SegTermDocsChild *child;
    InStream         *freq_stream;
    
    /* local copies */
    child       = (SegTermDocsChild*)term_docs->child;
    freq_stream = child->freq_stream;
    
    while (1) {
        /* bail if we're out of docs */
        if (child->count == child->doc_freq) {
            return 0;
        }

        doc_code = freq_stream->read_vint(freq_stream);
        child->doc  += doc_code >> 1;

        /* if the stored num was odd, the freq is 1 */ 
        if (doc_code & 1) {
            child->freq = 1;
        }
        /* otherwise, freq was stored as a VInt. */
        else {
            child->freq = child->freq_stream->read_vint(child->freq_stream);
        } 

        child->count++;

        /* if the doc isn't deleted... success! */
        if (!Kino_BitVec_get(child->deldocs, child->doc))
            break;
    }
    return 1;
}

void 
Kino_SegTermDocs_destroy(TermDocs *term_docs){
    SegTermDocsChild *child;
    child = (SegTermDocsChild*)term_docs->child;

    SvREFCNT_dec(child->positions);
    SvREFCNT_dec(child->freq_stream_sv);
    SvREFCNT_dec(child->prox_stream_sv);
    SvREFCNT_dec(child->deldocs_sv);
    SvREFCNT_dec(child->reader_sv);

    Kino_Safefree(child);

    Kino_TermDocs_destroy(term_docs);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegTermDocs - single-segment TermDocs

=head1 DESCRIPTION

Single-segment implemetation of KinoSearch::Index::TermDocs.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.12.

=end devdocs
=cut
