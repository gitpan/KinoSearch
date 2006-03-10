package KinoSearch::Analysis::TokenBatch;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Analysis::TokenBatch

TokenBatch*
new(...)
CODE:
    RETVAL = Kino_TokenBatch_new();
OUTPUT: RETVAL

void
add_token(obj, text, start_offset, end_offset)
    TokenBatch *obj;
    SV         *text;
    U32         start_offset;
    U32         end_offset;
PPCODE:
    Kino_TokenBatch_add_token(obj, text, start_offset, end_offset);

void
add_many_tokens(obj, raw_av)
    TokenBatch *obj;
    AV         *raw_av;
PREINIT:
    int   i, max;
    SV  **sv_ptr;
    SV   *text;
    U32   start_offset;
    U32   end_offset;
PPCODE:
    max = av_len(raw_av);
    if ( (max + 1) % 3 != 0) 
        Kino_confess("Expecting array to have mult3 elements");
    for (i = 0; i < max; i += 3) {
        sv_ptr = av_fetch(raw_av, i, 0);
        if (sv_ptr == NULL)
            Kino_confess("Failed to retrieve array element");
        text = *sv_ptr;
        sv_ptr = av_fetch(raw_av, (i+1), 0);
        if (sv_ptr == NULL)
            Kino_confess("Failed to retrieve array element");
        start_offset = (U32)SvUV(*sv_ptr);
        sv_ptr = av_fetch(raw_av, (i+2), 0);
        if (sv_ptr == NULL)
            Kino_confess("Failed to retrieve array element");
        end_offset = (U32)SvUV(*sv_ptr);
        Kino_TokenBatch_add_token(obj, text, start_offset, end_offset);
    }

=begin comment

Add the postings to the segment.  Postings are serialized and dumped into a
Sort::External sort pool.  The actual writing takes place later.

The serialization algo is designed so that postings emerge from the sort
pool in the order ideal for writing an index after a  simple lexical sort.
The concatenated components are:

    field number
    term text 
    document number
    positions (C array of U32)
    term length

=end comment
=cut

void
build_posting_list(obj, doc_num, field_num)
    TokenBatch *obj;
    U32         doc_num;
    U16         field_num;
PPCODE:
    Kino_TokenBatch_build_plist(obj, doc_num, field_num);


SV*
_set_or_get(obj, ...) 
    TokenBatch *obj;
ALIAS:
    set_start_offset = 1
    get_start_offset = 2
    set_end_offset   = 3
    get_end_offset   = 4
    set_text         = 5
    get_text         = 6
    set_all_texts    = 7
    get_all_texts    = 8
    set_size         = 9
    get_size         = 10
    set_postings     = 11
    get_postings     = 12
    set_tv_string    = 13
    get_tv_string    = 14
CODE:
{
    /* fail if looking for info on a single token but there isn't one */
    if (    ( ix < 7 )
         && ( obj->size == 0 || obj->current == -1)
    ) {
        Kino_confess("TokenBatch doesn't currently hold a valid token");
    }

    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        Kino_confess("usage: $term_info->set_xxxxxx($val)");

    switch (ix) {

    case 1:  obj->start_offsets[ obj->current ] = SvUV( ST(1) );
             /* fall through */
    case 2:  RETVAL = newSVuv( obj->start_offsets[ obj->current ] );
             break;

    case 3:  obj->end_offsets[ obj->current ] = SvUV( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVuv( obj->end_offsets[ obj->current ] );
             break;
        
    case 5:  av_store( obj->texts, obj->current, newSVsv( ST(1) ) );
             /* fall through */
    case 6:  {
                SV **sv_ptr;
                sv_ptr = av_fetch(obj->texts, obj->current, 0);
                if (sv_ptr == NULL)
                    RETVAL = newSV(0);
                else 
                    RETVAL =  newSVsv(*sv_ptr);
             }
             break;

    case 7:  Kino_confess("can't set_all_texts");
             /* fall through */
    case 8:  RETVAL = newRV_inc( (SV*)obj->texts );
             break;

    case 9:  Kino_confess("Can't set size on a TokenBatch object");
             /* fall through */
    case 10: RETVAL = newSVuv(obj->size);
             break;
    
    case 11: Kino_confess("can't set_postings");
             /* fall through */
    case 12: RETVAL = newRV_inc( (SV*)obj->postings );
             break;

    case 13: Kino_confess("can't set_tv_string");
             /* fall through */
    case 14: RETVAL = obj->tv_string == NULL
                ? newSV(0)
                : newSVsv( obj->tv_string );
             break;
    }
}
OUTPUT: RETVAL

bool
next(obj)
    TokenBatch *obj;
CODE:
    RETVAL = Kino_TokenBatch_next(obj);
OUTPUT: RETVAL

void
DESTROY(obj)
    TokenBatch *obj;
PPCODE:
    Kino_TokenBatch_destroy(obj);


__H__

#ifndef H_KINOSEARCH_ANALYSIS_TOKENBATCH
#define H_KINOSEARCH_ANALYSIS_TOKENBATCH 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "KinoSearchIndexTerm.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilEndianUtils.h"
#include "KinoSearchUtilMemManager.h"

typedef struct tokenbatch {
    AV  *texts;
    AV  *postings;
    SV  *tv_string;
    U32 *start_offsets;
    U32 *end_offsets;
    I32  capacity;
    I32  size;
    I32  current;
} TokenBatch;

TokenBatch* Kino_TokenBatch_new();
void Kino_TokenBatch_destroy(TokenBatch*);
void Kino_TokenBatch_add_token(TokenBatch*, SV*, U32, U32);
U32 Kino_TokenBatch_next(TokenBatch*);
void Kino_TokenBatch_build_plist(TokenBatch*, U32, U16);

#endif /* include guard */

__C__

#include "KinoSearchAnalysisTokenBatch.h"

TokenBatch*
Kino_TokenBatch_new() {
    TokenBatch *batch;

    /* allocate or flag as not allocated */
    Kino_New(0, batch, 1, TokenBatch);
    batch->texts         = newAV();
    batch->start_offsets = NULL;
    batch->end_offsets   = NULL;

    /* init */
    batch->capacity     = 0;
    batch->size         = 0;
    batch->current      = -1;
    batch->tv_string    = NULL;
    batch->postings     = NULL;

    return batch;
}


void
Kino_TokenBatch_destroy(TokenBatch *batch) {
    SvREFCNT_dec( (SV*)batch->texts );
    if (batch->postings != NULL)
        SvREFCNT_dec( (SV*)batch->postings );
    if (batch->tv_string != NULL)
        SvREFCNT_dec(batch->tv_string);
    Kino_Safefree(batch->start_offsets);
    Kino_Safefree(batch->end_offsets);
    Kino_Safefree(batch);
}

U32
Kino_TokenBatch_next(TokenBatch *batch) {
    batch->current =
          batch->size == 0                   ? -1
        : batch->current == (batch->size -1) ? -1 
        : batch->current + 1;
    int ret = batch->current == -1 ? 0 : 1;
    return batch->current == -1 ? 0 : 1;
}

void
Kino_TokenBatch_add_token(TokenBatch *batch, SV *text, U32 start_offset,
                          U32 end_offset) {
    SV *text_copy;

    if (batch->size >= batch->capacity) {
        batch->capacity += 100;
        av_extend(batch->texts, batch->capacity);
        Kino_Renew(batch->start_offsets, batch->capacity, U32);
        Kino_Renew(batch->end_offsets, batch->capacity, U32);
    }

    text_copy = newSVsv(text);
    av_store(batch->texts, batch->size, text_copy);
    batch->start_offsets[ batch->size ] = start_offset;
    batch->end_offsets[ batch->size ]   = end_offset;
    batch->size++;
}

#define POSDATA_LEN 12 

/* Encode postings in the serialized format expected by PostingsWriter, plus 
 * the term vector expected by FieldsWriter. */
void
Kino_TokenBatch_build_plist(TokenBatch *batch, U32 doc_num, U16 field_num) {
    char     doc_num_buf[4];
    char     field_num_buf[2];
    char     text_len_buf[2];
    char     vint_buf[5];
    HV      *pos_hash;
    HE      *he;
    AV      *out_av;
    U32      i, overlap, num_bytes, num_positions;
    U32      num_postings = 0;
    SV     **sv_ptr;
    SV      *text_sv;
    char    *text, *source_ptr, *dest_ptr, *end_ptr;
    char    *last_text = "";
    STRLEN   text_len, len, fake_len;
    STRLEN   last_len = 0;
    SV      *serialized_sv;
    SV      *tv_string_sv;
    U32     *source_u32, *dest_u32, *end_u32;

    /* prepare doc num and field num in anticipation of upcoming loop */
    Kino_encode_bigend_U32(doc_num, doc_num_buf);
    Kino_encode_bigend_U16(field_num, field_num_buf);


    /* build a posting list hash */
    pos_hash = newHV();
    for (i = 0; i < batch->size; i++) {
        /* the keys of the hash are the token texts */
        sv_ptr = av_fetch(batch->texts, i, 0);
        if (sv_ptr == NULL)
            continue;
        else 
            text_sv = *sv_ptr;

        /* either start a new hash entry or retrieve an existing one */
        if (!hv_exists_ent(pos_hash, text_sv, 0)) {
            /* the values are the serialized scalars */
            text = SvPV(text_sv, text_len);
            if (text_len > 65535) 
                Kino_confess("Maximum token length is 65535; got %"UVuf, 
                    (UV)text_len);
            Kino_encode_bigend_U16(text_len, text_len_buf);

            /* allocate the serialized scalar */
            len =   2                  /* for now, put text_len at top */
                  + KINO_FIELD_NUM_LEN 
                  + text_len           /* term text */
                  + 4                  /* length of encoded doc_num */
                  + POSDATA_LEN
                  + 2                  /* eventually, text_len goes at end */
                  + 1;                 /* null byte */ 
            serialized_sv = newSV(len);
            SvPOK_on(serialized_sv);
            source_ptr = SvPVX(serialized_sv);
            dest_ptr   = source_ptr;

            /* concatenate a bunch of stuff onto the serialized scalar */
            Copy(text_len_buf, dest_ptr, 2, char);
            dest_ptr += 2;
            Copy(field_num_buf, dest_ptr, KINO_FIELD_NUM_LEN, char);
            dest_ptr += KINO_FIELD_NUM_LEN;
            Copy(text, dest_ptr, text_len, char);
            dest_ptr += text_len;
            Copy(doc_num_buf, dest_ptr, 4, char);
            dest_ptr += 4;
            SvCUR_set(serialized_sv, (dest_ptr - source_ptr)); 

            /* store the text => serialized_sv pair in the pos_hash */
            (void)hv_store_ent(pos_hash, text_sv, serialized_sv, 0); 
        }
        else {
            /* retrieve the serialized scalar and allocate more space */
            he = hv_fetch_ent(pos_hash, text_sv, 0, 0);
            serialized_sv = HeVAL(he);
            len = SvCUR(serialized_sv)
                + POSDATA_LEN /* allocate space for upcoming posdata */
                + 2  /* extra space for encoded text length */
                + 1; /* null byte */
            SvGROW( serialized_sv, len );
        }

        /* append position, start offset, end offset to the serialized_sv */
        dest_u32 = (U32*)SvEND(serialized_sv);
        *dest_u32++ = i;
        *dest_u32++ = batch->start_offsets[i];
        *dest_u32++ = batch->end_offsets[i];
        len = SvCUR(serialized_sv) + POSDATA_LEN;
        SvCUR_set(serialized_sv, len);
    }

    /* allocate and presize the array to hold the output */
    num_postings = hv_iterinit(pos_hash);
    out_av = newAV();
    av_extend(out_av, num_postings);

    /* collect serialized scalars into an array */
    i = 0;
    while (he = hv_iternext(pos_hash)) {
        serialized_sv = HeVAL(he);

        /* transfer text_len to end of serialized scalar */
        source_ptr = SvPVX(serialized_sv);
        dest_ptr   = SvEND(serialized_sv);
        SvGROW(serialized_sv, SvCUR(serialized_sv) + 3);
        Copy(source_ptr, dest_ptr, 2, char);
        SvCUR(serialized_sv) += 2;
        source_ptr += 2;
        sv_chop(serialized_sv, source_ptr);

        SvREFCNT_inc(serialized_sv);
        av_store(out_av, i, serialized_sv);
        i++;
    }

    /* we're done with the pos_hash, so kill it off */
    SvREFCNT_dec(pos_hash);

    /* start the term vector string */
    tv_string_sv = newSV(20);
    SvPOK_on(tv_string_sv);
    num_bytes = Kino_OutStream_encode_vint(num_postings, vint_buf);
    sv_catpvn(tv_string_sv, vint_buf, num_bytes);

    /* sort the posting lists lexically */
    sortsv(AvARRAY(out_av), num_postings, Perl_sv_cmp);

    /* iterate through the array, making changes to the serialized scalars */
    for (i = 0; i < num_postings; i++) {
        serialized_sv = *(av_fetch(out_av, i, 0));

        /* find the beginning of the term text */
        text = SvPV(serialized_sv, fake_len);
        text += KINO_FIELD_NUM_LEN;

        /* save the text_len; we'll move it forward later */
        end_ptr = SvEND(serialized_sv) - 2;
        text_len = Kino_decode_bigend_U16( end_ptr );
        Kino_encode_bigend_U16(text_len, text_len_buf);

        source_ptr = SvPVX(serialized_sv) + KINO_FIELD_NUM_LEN + text_len + 4;
        source_u32 = (U32*)source_ptr;
        dest_u32   = source_u32;
        end_u32    = (U32*)end_ptr;

        /* append the string diff to the tv_string */
        overlap = Kino_StrHelp_string_diff(last_text, text, 
            last_len, text_len);
        num_bytes = Kino_OutStream_encode_vint(overlap, vint_buf);
        sv_catpvn( tv_string_sv, vint_buf, num_bytes );
        num_bytes = Kino_OutStream_encode_vint(
            (text_len - overlap), vint_buf );
        sv_catpvn( tv_string_sv, vint_buf, num_bytes );
        sv_catpvn( tv_string_sv, (text + overlap), (text_len - overlap) );

        /* append the number of positions for this term */
        num_positions =   SvCUR(serialized_sv) 
                        - KINO_FIELD_NUM_LEN
                        - text_len
                        - 4  /* doc num */
                        - 2; /* encoded text len */
        num_positions /= POSDATA_LEN;
        num_bytes = Kino_OutStream_encode_vint(num_positions, vint_buf);
        sv_catpvn( tv_string_sv, vint_buf, num_bytes );

        while (source_u32 < end_u32) {
            /* keep only the positions in the serialized scalars */
            num_bytes = Kino_OutStream_encode_vint(*source_u32, vint_buf);
            sv_catpvn( tv_string_sv, vint_buf, num_bytes );
            *dest_u32++ = *source_u32++;

            /* add start_offset to tv_string */
            num_bytes = Kino_OutStream_encode_vint(*source_u32, vint_buf);
            sv_catpvn( tv_string_sv, vint_buf, num_bytes );
            source_u32++;

            /* add end_offset to tv_string */
            num_bytes = Kino_OutStream_encode_vint(*source_u32, vint_buf);
            sv_catpvn( tv_string_sv, vint_buf, num_bytes );
            source_u32++;
        }

        /* restore the text_len and close the scalar */
        dest_ptr = (char*)dest_u32;
        Copy(text_len_buf, dest_ptr, 2, char);
        dest_ptr += 2;
        len = dest_ptr - SvPVX(serialized_sv);
        SvCUR_set(serialized_sv, len);

        last_text = text;
        last_len  = text_len;
    }
    
    if (batch->tv_string != NULL)
        SvREFCNT_dec(batch->tv_string);
    batch->tv_string = tv_string_sv;
    if (batch->postings != NULL)
        SvREFCNT_dec(batch->postings);
    batch->postings = out_av;
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Analysis::TokenBatch

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut


