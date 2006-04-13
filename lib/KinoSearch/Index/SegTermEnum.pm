package KinoSearch::Index::SegTermEnum;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Index::Term;
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::TermBuffer;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params
    finfos   => undef,
    instream => undef,
    is_index => 0,
);

sub new {
    # verify params
    my $ignore = shift;
    my %args = ( %instance_vars, @_ );
    verify_args( \%instance_vars, %args );

    # get a TermBuffer helper object
    my $term_buffer
        = KinoSearch::Index::TermBuffer->new( finfos => $args{finfos}, );

    return _new_helper( @args{ 'instream', 'is_index', 'finfos', },
        $term_buffer );
}

sub clone_enum {
    my $self = shift;

    # dupe instream and seek it to the start of the file, so init works right
    my $instream   = $self->_get_instream;
    my $new_stream = $instream->clone_stream;
    $new_stream->seek(0);

    # create a new object and seek it to the right term/terminfo
    my $evil_twin = __PACKAGE__->new(
        finfos   => $self->_get_finfos,
        instream => $new_stream,
        is_index => $self->is_index,
    );
    $evil_twin->seek(
        $instream->tell,       $self->_get_position,
        $self->get_termstring, $self->get_term_info
    );
    return $evil_twin;
}

# Locate the Enum to a particular spot.
sub seek {
    my ( $self, $pointer, $position, $termstring, $tinfo ) = @_;

    # seek the filehandle
    my $instream = $self->_get_instream;
    $instream->seek($pointer);

    # set values as if we'd scanned here from the start of the Enum
    $self->_set_position($position);
    $self->_set_termstring($termstring);
    $self->_set_term_info($tinfo);
}

sub close {
    my $instream = $_[0]->get_instream;
    $instream->close;
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::SegTermEnum 


SegTermEnum*
_new_helper(instream_sv, is_index, finfos_sv, term_buffer_sv)
    SV         *instream_sv;
    I32         is_index;
    SV         *finfos_sv
    SV         *term_buffer_sv;
CODE:
    RETVAL = Kino_SegTermEnum_new_helper(instream_sv, is_index, finfos_sv,
        term_buffer_sv);
OUTPUT: RETVAL


=for comment

fill_cache() loads the entire Enum into memory.  This should only be called
for index Enums -- never for primary Enums.

=cut

void
fill_cache(obj)
    SegTermEnum *obj;
PPCODE:
    Kino_SegTermEnum_fill_cache(obj);


=begin comment

scan_to() iterates through the Enum until the Enum's state is ge the target.
This is called on the main Enum, after seek() has gotten it close.  You don't
want to scan through the entire main Enum, just through a small part.

Scanning through an Enum is an involved process, due to the heavy data
compression.  See the Java Lucene File Format definition for details.

=end comment
=cut

void
scan_to(obj, target_termstring_sv)
    SegTermEnum *obj;
    SV          *target_termstring_sv;
PPCODE:
    Kino_SegTermEnum_scan_to(obj, target_termstring_sv);


=for comment

Reset the Enum to the top, so that after next() is called, the Enum is located
at the first term in the segment.

=cut

void
reset(obj)
    SegTermEnum *obj;
PPCODE:
    Kino_SegTermEnum_reset(obj);


=for comment

next() advances the state of the Enum one term.  If the current position of
the Enum is valid, it returns 1; when the Enum is exhausted, it returns 0.

=cut

IV
next(obj)
    SegTermEnum *obj;
CODE:
    RETVAL = Kino_SegTermEnum_next(obj);
OUTPUT: RETVAL


=for comment

For an Enum which has been loaded into memory, scan to the target as quickly
as possible.

=cut

I32
scan_cache(obj, target_termstring_sv)
    SegTermEnum  *obj;
    SV           *target_termstring_sv;
CODE:
    RETVAL = Kino_SegTermEnum_scan_cache(obj, target_termstring_sv);
OUTPUT: RETVAL


=for comment

Setters and getters for members in the SegTermEnum struct. Not all of these 
are useful.

=cut

SV*
_set_or_get(obj, ...)
    SegTermEnum *obj;
ALIAS:
        _set_instream        = 1
        _get_instream        = 2
        _set_finfos          = 3
        _get_finfos          = 4
        _set_size            = 5
    get_size                 = 6  
        _set_termstring      = 7
    get_termstring           = 8
        _set_term_info       = 9
    get_term_info            = 10
        _set_index_interval  = 11
    get_index_interval       = 12
        _set_position        = 13
        _get_position        = 14
        _set_is_index        = 15
    is_index                 = 16
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $seg_term_enum->set_xxxxxx($val)");

    switch (ix) {

    case 0:  croak("can't call _get_or_set on it's own");
             break; /* probably unreachable */

    case 1:  SvREFCNT_dec(obj->instream_sv);
             obj->instream_sv = newSVsv( ST(1) );
             /* fall through */
    case 2:  RETVAL = newSVsv(obj->instream_sv); 
             break;

    case 3:  SvREFCNT_dec(obj->finfos);
             obj->finfos = newSVsv( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVsv(obj->finfos); 
             break;

    case 5:  obj->enum_size = (I32)SvIV( ST(1) ); 
             /* fall through */
    case 6:  RETVAL = newSViv(obj->enum_size); 
             break;

    case 7:  if ( SvOK( ST(1) ) ) {
                 char *scratch_ptr;
                 STRLEN len;
                 scratch_ptr = SvPV( ST(1), len );
                 if (len < KINO_FIELD_NUM_LEN)
                    Kino_confess("Internal error: termstring too short");
                 Kino_TermBuf_set_text_len(obj->term_buf, 
                    len - KINO_FIELD_NUM_LEN);
                 Copy(scratch_ptr, obj->term_buf->termstring, len, char);
             }
             else {
                 Kino_TermBuf_reset(obj->term_buf);
             }
             /* fall through */
    case 8:  RETVAL = (obj->term_buf->termstring == NULL) 
                 ? &PL_sv_undef
                 : newSVpv( obj->term_buf->termstring,
                     (obj->term_buf->text_len + KINO_FIELD_NUM_LEN) ); 
             break;

    case 9:  {
                TermInfo* new_tinfo;
                Kino_extract_struct( ST(1), new_tinfo, TermInfo*, 
                    "KinoSearch::Index::TermInfo");
                Kino_TInfo_destroy(obj->tinfo);
                obj->tinfo = Kino_TInfo_dupe(new_tinfo);
             }
             /* fall through */
    case 10: {
                TermInfo* new_tinfo;
                RETVAL = newSV(0);
                new_tinfo = Kino_TInfo_dupe(obj->tinfo);
                sv_setref_pv(RETVAL, "KinoSearch::Index::TermInfo", 
                              (void*)new_tinfo);
             }
             break;

    case 11: obj->index_interval = SvIV( ST(1) );
             /* fall through */
    case 12: RETVAL = newSViv(obj->index_interval);
             break;

    case 13: obj->position = SvIV( ST(1) );
             /* fall through */
    case 14: RETVAL = newSViv(obj->position);
             break;

    case 15: Kino_confess("can't set is_index");
             /* fall through */
    case 16: RETVAL = newSViv(obj->is_index);
             break;

    default: Kino_confess("Internal error: _set_or_get ix: %d", ix); 
             break; /* probably unreachable */
    }
}
    OUTPUT: RETVAL


void
DESTROY(obj)
    SegTermEnum* obj;
PPCODE:
    Kino_SegTermEnum_destroy(obj);

__H__

#ifndef H_KINOSEARCH_INDEX_SEG_TERM_ENUM
#define H_KINOSEARCH_INDEX_SEG_TERM_ENUM 1

#include "EXTERN.h"
#include "perl.h"
#include "KinoSearchIndexTermBuffer.h"
#include "KinoSearchIndexTermInfo.h"
#include "KinoSearchStoreInStream.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilCClass.h"
#include "KinoSearchUtilMemManager.h"
#include "KinoSearchUtilStringHelper.h"

typedef struct segtermenum {
    SV         *finfos;
    SV         *instream_sv;
    SV         *term_buf_ref;
    TermBuffer *term_buf;
    TermInfo   *tinfo;
    InStream   *instream;
    I32         is_index;
    I32         enum_size;
    I32         position;
    I32         index_interval;
    I32         skip_interval;
    char      **termstring_ptr_cache;
    STRLEN     *term_text_len_cache;
    TermInfo  **tinfos_cache;
} SegTermEnum;


SegTermEnum* Kino_SegTermEnum_new_helper(SV*, I32, SV*, SV*);
void Kino_SegTermEnum_reset(SegTermEnum*);
I32  Kino_SegTermEnum_next(SegTermEnum*);
void Kino_SegTermEnum_fill_cache(SegTermEnum*);
void Kino_SegTermEnum_scan_to(SegTermEnum*, SV*);
I32  Kino_SegTermEnum_scan_cache(SegTermEnum*, SV*);
void Kino_SegTermEnum_destroy(SegTermEnum*);

#endif /* include guard */

__C__

#include "KinoSearchIndexSegTermEnum.h"

SegTermEnum*
Kino_SegTermEnum_new_helper(SV *instream_sv, I32 is_index, SV *finfos_sv,
                            SV *term_buffer_sv) {
    I32           format;
    InStream     *instream;
    SegTermEnum  *obj;

    /* allocate */
    Kino_New(0, obj, 1, SegTermEnum);
    obj->tinfo = Kino_TInfo_new();

    /* flag these so they don't get freed unless they get filled later */
    obj->tinfos_cache         = NULL;
    obj->termstring_ptr_cache = NULL;
    obj->term_text_len_cache  = NULL;

    /* save instream, finfos, and term_buffer, incrementing refcounts */
    obj->instream_sv  = newSVsv(instream_sv);
    obj->finfos       = newSVsv(finfos_sv);
    obj->term_buf_ref = newSVsv(term_buffer_sv);
    Kino_extract_struct(term_buffer_sv, obj->term_buf, TermBuffer*, 
        "KinoSearch::Index::TermBuffer");
    Kino_extract_struct(instream_sv, obj->instream, InStream*, 
        "KinoSearch::Store::InStream");
    instream = obj->instream;

    /* determine whether this is a primary or index enum */
    obj->is_index = is_index;

    /* reject older or newer index formats */
    format = (I32)instream->read_int(instream);
    if (format != -2)
        Kino_confess("Unsupported index format: %d", format);

    /* read in some vars */
    obj->enum_size      = instream->read_long(instream);
    obj->index_interval = instream->read_int(instream);
    obj->skip_interval  = instream->read_int(instream);

    /* define the position of the Enum as "not yet started" */
    obj->position = -1;
    
    return obj;
}

#define KINO_SEG_TERM_ENUM_HEADER_LEN 20 

void
Kino_SegTermEnum_reset(SegTermEnum* obj) {
    obj->position = -1;
    obj->instream->seek(obj->instream, KINO_SEG_TERM_ENUM_HEADER_LEN);
    Kino_TermBuf_reset(obj->term_buf);
    Kino_TInfo_reset(obj->tinfo);
}

I32 
Kino_SegTermEnum_next(SegTermEnum *obj) {
    InStream *instream;
    TermInfo *tinfo;

    /* make some local copies for clarity of code */
    instream = obj->instream;
    tinfo    = obj->tinfo;

    /* if we've run out of terms, null out the termstring and return */
    if (++obj->position >= obj->enum_size) {
        Kino_TermBuf_reset(obj->term_buf);
        return 0;
    }

    /* read in the term */
    Kino_TermBuf_read(obj->term_buf, instream);

    /* read doc freq */
    tinfo->doc_freq = instream->read_vint(instream);

    /* adjust file pointers. */
    tinfo->frq_fileptr += instream->read_vlong(instream);
    tinfo->prx_fileptr += instream->read_vlong(instream);

    /* read skip data (which doesn't do anything right now) */
    if (tinfo->doc_freq >= obj->skip_interval)
        tinfo->skip_offset = instream->read_vint(instream);
    else
        tinfo->skip_offset = 0;

    /* read filepointer to main enum if this is an index enum */
    if (obj->is_index)
        tinfo->index_fileptr += instream->read_vlong(instream);

    return 1;
}

void
Kino_SegTermEnum_fill_cache(SegTermEnum* obj) {
    TermBuffer  *term_buf;
    TermInfo    *tinfo;
    TermInfo   **tinfos_cache;
    STRLEN      *term_text_len_cache;
    char       **termstring_ptr_cache;

    /* allocate space for cache pointers */
    if (obj->tinfos_cache != NULL)
        Kino_confess("Internal error: cache already filled");
    Kino_New(0, obj->termstring_ptr_cache, obj->enum_size, char*); 
    Kino_New(0, obj->term_text_len_cache, obj->enum_size, STRLEN);
    Kino_New(0, obj->tinfos_cache, obj->enum_size, TermInfo*);

    /* make some local copies */
    tinfo                = obj->tinfo;
    term_buf             = obj->term_buf;
    tinfos_cache         = obj->tinfos_cache;
    term_text_len_cache  = obj->term_text_len_cache;
    termstring_ptr_cache = obj->termstring_ptr_cache;

    while (Kino_SegTermEnum_next(obj)) {
        /* copy tinfo and termstring into caches */
        *tinfos_cache++         = Kino_TInfo_dupe(tinfo);
        *term_text_len_cache++  = term_buf->text_len;
        *termstring_ptr_cache++ = Kino_savepvn(term_buf->termstring, 
            (term_buf->text_len + KINO_FIELD_NUM_LEN));
    }
}

void
Kino_SegTermEnum_scan_to(SegTermEnum *obj, SV *target_termstring_sv) {
    TermBuffer *term_buf;
    char       *target_termstring;
    STRLEN      target_termstring_len;
    I32         comparison; 

    /* make local copy */
    term_buf = obj->term_buf;

    target_termstring = SvPV(target_termstring_sv, target_termstring_len);

    /* keep looping until the termstring is lexically ge target */
    do {
        comparison = Kino_StrHelp_compare_strings(
            term_buf->termstring, 
            target_termstring, 
            (term_buf->text_len + KINO_FIELD_NUM_LEN), 
            target_termstring_len
        );
        if (comparison >= 0 && obj->position != -1)
            break;
    } while (Kino_SegTermEnum_next(obj));
}

I32
Kino_SegTermEnum_scan_cache(SegTermEnum *obj, SV *target_termstring_sv) {
    TermBuffer  *term_buf;
    I32          lo, mid, hi, result, comparison;
    char        *target_termstring;
    STRLEN       target_len;
    char       **termstrings;
    STRLEN      *lengths;
    char        *scratch_ptr;
    STRLEN       term_text_len;

    term_buf = obj->term_buf;

    /* prepare to compare strings */
    target_termstring = SvPV(target_termstring_sv, target_len);
    termstrings       = obj->termstring_ptr_cache;
    lengths           = obj->term_text_len_cache;
    if (obj->tinfos_cache == NULL)
        Kino_confess("Internal Error: fill_cache hasn't been called yet"); 
    
    lo     = 0;
    hi     = obj->enum_size - 1;
    result = -100; 

    /* divide and conquer */
    while (hi >= lo) {
        mid        = (lo + hi) >> 1;
        comparison = Kino_StrHelp_compare_strings(
            target_termstring,  
            termstrings[mid], 
            target_len,        
            (lengths[mid] + KINO_FIELD_NUM_LEN)
        );
        if (comparison < 0) 
            hi = mid - 1;
        else if (comparison > 0)
            lo = mid + 1;
        else {
            result = mid;
            break;
        }
    }
    result = hi     == -1   ? 0  /* indicating that target lt first entry */
           : result == -100 ? hi /* if result is still -100, it wasn't set */
           : result;
    
    /* set the state of the Enum/TermBuffer as if we'd called scan_to */
    obj->position  = result;
    term_text_len  = lengths[result]; 
    scratch_ptr    = termstrings[result];
    Kino_TermBuf_set_text_len(term_buf, term_text_len);
    Copy(scratch_ptr, term_buf->termstring, 
        (term_text_len + KINO_FIELD_NUM_LEN), char);

    Kino_TInfo_destroy(obj->tinfo);
    obj->tinfo = Kino_TInfo_dupe( obj->tinfos_cache[result] );

    return result;
}

void
Kino_SegTermEnum_destroy(SegTermEnum *obj) {
    I32         iter;
    char      **termstring_ptr_cache_ptr;
    TermInfo  **tinfos_cache_ptr;

    /* put out the garbage for collection */
    SvREFCNT_dec(obj->finfos);
    SvREFCNT_dec(obj->instream_sv);
    SvREFCNT_dec(obj->term_buf_ref);

    Kino_TInfo_destroy(obj->tinfo);

    /* if fill_cache was called, free all of that... */
    if (obj->tinfos_cache != NULL) {
        termstring_ptr_cache_ptr = obj->termstring_ptr_cache;
        tinfos_cache_ptr = obj->tinfos_cache;
        Kino_Safefree(obj->term_text_len_cache);
        for (iter = 0; iter < obj->enum_size; iter++) {
            Kino_Safefree(*termstring_ptr_cache_ptr++);
            Kino_TInfo_destroy(*tinfos_cache_ptr++);
        }
        Kino_Safefree(obj->tinfos_cache);
        Kino_Safefree(obj->termstring_ptr_cache);
    }

    /* last, the SegTermEnum object itself */
    Kino_Safefree(obj);
}


__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegTermEnum - single-segment TermEnum

=head1 DESCRIPTION

Single-segment implementation of KinoSearch::Index::TermEnum.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut


