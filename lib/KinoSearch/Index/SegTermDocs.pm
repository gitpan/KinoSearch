package KinoSearch::Index::SegTermDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermDocs );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    reader       => undef,
);

sub new {
    my $self = shift->SUPER::new;
    verify_args(\%instance_vars, @_);
    my %args = (%instance_vars, @_);

    _init_child($self);

    # dupe some stuff from the parent reader.
    $self->_set_reader( $args{reader} );
    $self->_set_freq_fh( $args{reader}->get_freq_stream()->clone_stream );
    $self->_set_prox_fh( $args{reader}->get_prox_stream()->clone_stream );
    $self->_set_deldocs( $args{reader}->get_deldocs );

    return $self;
}

sub seek {
    my ( $self, $thing ) = @_;
    # reset count
    $self->_set_count(0);

    my $tinfo = $self->_derive_term_info($thing);

    if ( !defined($tinfo) ) {
        # no terminfo means no docs - the term isn't in this segment
        $self->set_doc_freq(0);
    }
    else {
        # yes terminfo means we know the doc_freq and the file pointer
        $self->set_doc(0);
        $self->set_doc_freq( $tinfo->get_doc_freq );
        $self->_get_freq_fh()->seek( $tinfo->get_frq_fileptr );
        $self->_get_prox_fh()->seek( $tinfo->get_prx_fileptr );
    }
}

sub _derive_term_info {
    my ( $self, $thing ) = @_;
    my $tinfo;

    # make every effort to secure a TermInfo
    if ( !defined $thing ) {
        # do nothing -- leave $tinfo undef
    }
    elsif ( !blessed($thing) ) {
        confess("Internal error: Don't know how to deal with '$thing'");
    }
    elsif ( $thing->isa('KinoSearch::Index::Term') ) {
        $tinfo = $self->_get_reader()->fetch_term_info($thing);
    }
    elsif ( $thing->isa('KinoSearch::Index::TermInfo') ) {
        $tinfo = $thing;
    }
    elsif ( $thing->isa('KinoSearch::Index::TermEnum') ) {
        $tinfo = $thing->get_term_info;
    }

    return $tinfo;
}

sub close { 
    my $self = shift;
    $self->_get_freq_fh()->close;
    $self->_get_prox_fh()->close;
}

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::SegTermDocs


void
_init_child(obj)
    TermDocs  *obj;
PPCODE:
    Kino_SegTermDocs_init_child(obj);

U32
read(obj, doc_nums_sv, freqs_sv, num_wanted)
    TermDocs  *obj
    SV        *doc_nums_sv;
    SV        *freqs_sv;
    U32        num_wanted;
CODE:
    RETVAL = Kino_SegTermDocs_read(obj, doc_nums_sv, freqs_sv, num_wanted);
OUTPUT: RETVAL

SV*
_set_or_get(obj, ...)
    TermDocs*obj;
ALIAS:
    _set_count         = 1
    _get_count         = 2
    _set_freq_fh       = 3
    _get_freq_fh       = 4
    _set_prox_fh       = 5
    _get_prox_fh       = 6
    _set_deldocs       = 7
    _get_deldocs       = 8 
    _set_reader        = 9 
    _get_reader        = 10
    set_read_positions = 11
    get_read_positions = 12
PREINIT:
    SegTermDocsChild *child;
CODE:
{
    child = (SegTermDocsChild*)obj->child;

    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        Kino_confess("usage: $term_docs->set_xxxxxx($val)");

    switch (ix) {

    case 1:  child->count = SvUV(ST(1));
             /* fall through */
    case 2:  RETVAL = newSVuv(child->count);
             break;

    case 3:  if (child->freq_fh_sv != NULL)
                SvREFCNT_dec(child->freq_fh_sv);
             child->freq_fh    = IoIFP(sv_2io( ST(1) ));
             child->freq_fh_sv = newSVsv( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVsv(child->freq_fh_sv);
             break;

    case 5:  if (child->prox_fh_sv != NULL)
                SvREFCNT_dec(child->prox_fh_sv);
             child->prox_fh    = IoIFP(sv_2io( ST(1) ));
             child->prox_fh_sv = newSVsv( ST(1) );
             /* fall through */
    case 6:  RETVAL = newSVsv(child->prox_fh_sv);
             break;

    case 7:  if (child->deldocs_sv != NULL)
                SvREFCNT_dec(child->deldocs_sv);
             child->deldocs_sv = newSVsv( ST(1) );
             Kino_extract_struct( child->deldocs_sv, child->deldocs, 
                BitVector*, "KinoSearch::Index::DelDocs" );
             /* fall through */
    case 8:  RETVAL = newSVsv(child->deldocs_sv);
             break;

    case 9:  if (child->reader_sv != NULL)
                SvREFCNT_dec(child->reader_sv);
             if (!sv_derived_from( ST(1), "KinoSearch::Index::IndexReader") )
                Kino_confess("not a KinoSearch::Index::IndexReader");
             child->reader_sv = newSVsv( ST(1) );
             /* fall through */
    case 10: RETVAL = newSVsv(child->reader_sv);
             break;

    case 11: obj->next = SvTRUE( ST(1) ) 
                ? Kino_SegTermDocs_next_with_positions
                : Kino_SegTermDocs_next;
             /* fall through */
    case 12: RETVAL = obj->next == Kino_SegTermDocs_next_with_positions 
                ? newSViv(1) : newSViv(0);
             break;
    }
}
OUTPUT: RETVAL


void 
DESTROY(obj)
    TermDocs *obj;
PPCODE:
    Kino_SegTermDocs_destroy(obj);

__H__

#ifndef H_KINO_SEG_TERM_DOCS
#define H_KINO_SEG_TERM_DOCS 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilBitVector.h"
#include "KinoSearchIndexTermDocs.h"
#include "KinoSearchStoreInStream.h"
#include "KinoSearchUtilMemManager.h"

typedef struct segtermdocschild {
    U32        count;
    PerlIO    *freq_fh;
    PerlIO    *prox_fh;
    BitVector *deldocs;
    SV        *freq_fh_sv;
    SV        *prox_fh_sv;
    SV        *deldocs_sv;
    SV        *reader_sv;
} SegTermDocsChild;

void Kino_SegTermDocs_init_child(TermDocs*);
U32  Kino_SegTermDocs_read(TermDocs*, SV*, SV*, U32);
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

    term_docs->read  = Kino_SegTermDocs_read;
    term_docs->next  = Kino_SegTermDocs_next;

    child->freq_fh_sv   = NULL;
    child->prox_fh_sv   = NULL;
    child->deldocs_sv   = NULL;
    child->reader_sv    = NULL;
    child->count        = 0;
}

U32 
Kino_SegTermDocs_read(TermDocs *term_docs, SV* doc_nums_sv, SV* freqs_sv, 
                      U32 num_wanted) {
    SegTermDocsChild *child;
	U32               doc_code;
	U32              *doc_nums;
	U32              *freqs;
	STRLEN            len;
	U32               num_got = 0;

    child = (SegTermDocsChild*)term_docs->child;

    len = num_wanted * sizeof(U32);
    SvUPGRADE(doc_nums_sv, SVt_PV);
    SvUPGRADE(freqs_sv,    SVt_PV);
    SvPOK_on(doc_nums_sv);
    SvPOK_on(freqs_sv);
    doc_nums = (U32*)SvGROW(doc_nums_sv, len + 1);
    freqs    = (U32*)SvGROW(freqs_sv,    len + 1);

    while (child->count < term_docs->doc_freq && num_got < num_wanted) {
        /* manually inlined call to term_docs->next */ 
        child->count++;
        doc_code = Kino_IO_read_vint(child->freq_fh);
        term_docs->doc  += doc_code >> 1;
        if (doc_code & 1)
            term_docs->freq = 1;
        else
            term_docs->freq = Kino_IO_read_vint(child->freq_fh);

        /* if the doc isn't deleted... */
        if ( !Kino_BitVec_get(child->deldocs, term_docs->doc) ) {
            /* ... append to results */
            *doc_nums++ = term_docs->doc;
            *freqs++    = term_docs->freq;
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
    
    child = (SegTermDocsChild*)term_docs->child;
    
    while (1) {
        if (child->count == term_docs->doc_freq) {
            return 0;
        }

        doc_code = Kino_IO_read_vint(child->freq_fh);
        term_docs->doc  += doc_code >> 1;

        /* if the stored num was odd, the freq is 1 */ 
        if (doc_code & 1) {
            term_docs->freq = 1;
        }
        /* otherwise, freq was stored as a VInt. */
        else {
            term_docs->freq = Kino_IO_read_vint(child->freq_fh);
        } 

        child->count++;
        
        len = term_docs->freq * sizeof(U32);
        SvGROW( term_docs->positions, len );
        SvCUR_set(term_docs->positions, len);
        positions = (U32*)SvPVX(term_docs->positions);
        positions_end = (U32*)SvEND(term_docs->positions);
        while (positions < positions_end) {
            position += Kino_IO_read_vint(child->prox_fh);
            *positions++ = position;
        }

        if (!Kino_BitVec_get(child->deldocs, term_docs->doc))
            break;
    }
    return 1;
}

bool
Kino_SegTermDocs_next(TermDocs *term_docs) {
    U32               doc_code;
    SegTermDocsChild* child = (SegTermDocsChild*)term_docs->child;
    
    while (1) {
        if (child->count == term_docs->doc_freq) {
            return 0;
        }

        doc_code = Kino_IO_read_vint(child->freq_fh);
        term_docs->doc  += doc_code >> 1;

        /* if the stored num was odd, the freq is 1 */ 
        if (doc_code & 1) {
            term_docs->freq = 1;
        }
        /* otherwise, freq was stored as a VInt. */
        else {
            term_docs->freq = Kino_IO_read_vint(child->freq_fh);
        } 

        child->count++;

        if (!Kino_BitVec_get(child->deldocs, term_docs->doc))
            break;
    }
    return 1;
}

void 
Kino_SegTermDocs_destroy(TermDocs *term_docs){
    SegTermDocsChild *child = (SegTermDocsChild*)term_docs->child;
    SvREFCNT_dec(child->freq_fh_sv);
    SvREFCNT_dec(child->prox_fh_sv);
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

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut
