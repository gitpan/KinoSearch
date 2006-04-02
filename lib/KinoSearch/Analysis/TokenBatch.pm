package KinoSearch::Analysis::TokenBatch;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Analysis::TokenBatch

TokenBatch*
new(either_sv)
    SV *either_sv;
CODE:
    RETVAL = Kino_TokenBatch_new();
OUTPUT: RETVAL

=for comment

Add one token to the batch.

=cut

void
add_token(batch, text, start_offset, end_offset)
    TokenBatch *batch;
    SV         *text;
    U32         start_offset;
    U32         end_offset;
PPCODE:
    Kino_TokenBatch_add_token(batch, text, start_offset, end_offset);

=for comment

Add many tokens to the batch, by supplying the string to be tokenized, and
arrays of token starts and token ends (specified in bytes).

=cut

void
add_many_tokens(batch, string_sv, starts_av, ends_av)
    TokenBatch *batch;
    SV         *string_sv;
    AV         *starts_av;
    AV         *ends_av;
PPCODE:
    Kino_TokenBatch_add_many_tokens(batch, string_sv, starts_av, ends_av);


=begin comment

Add the postings to the segment.  Postings are serialized and dumped into a
SortExternal sort pool.  The actual writing takes place later.

The serialization algo is designed so that postings emerge from the sort
pool in the order ideal for writing an index after a  simple lexical sort.
The concatenated components are:

    field number
    term text 
    null byte
    document number
    positions (C array of U32)
    term length

=end comment
=cut

void
build_posting_list(batch, doc_num, field_num)
    TokenBatch *batch;
    U32         doc_num;
    U16         field_num;
PPCODE:
    Kino_TokenBatch_build_plist(batch, doc_num, field_num);


SV*
_set_or_get(batch, ...) 
    TokenBatch *batch;
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
         && ( batch->size == 0 || batch->current == -1)
    ) {
        Kino_confess("TokenBatch doesn't currently hold a valid token");
    }

    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        Kino_confess("usage: $term_info->set_xxxxxx($val)");

    switch (ix) {

    case 1:  batch->start_offsets[ batch->current ] = SvUV( ST(1) );
             /* fall through */
    case 2:  RETVAL = newSVuv( batch->start_offsets[ batch->current ] );
             break;

    case 3:  batch->end_offsets[ batch->current ] = SvUV( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVuv( batch->end_offsets[ batch->current ] );
             break;
        
    case 5:  av_store( batch->texts, batch->current, newSVsv( ST(1) ) );
             /* fall through */
    case 6:  {
                SV **sv_ptr;
                sv_ptr = av_fetch(batch->texts, batch->current, 0);
                if (sv_ptr == NULL)
                    RETVAL = &PL_sv_undef;
                else 
                    RETVAL =  newSVsv(*sv_ptr);
             }
             break;

    case 7:  Kino_confess("can't set_all_texts");
             /* fall through */
    case 8:  RETVAL = newRV_inc( (SV*)batch->texts );
             break;

    case 9:  Kino_confess("Can't set size on a TokenBatch object");
             /* fall through */
    case 10: RETVAL = newSVuv(batch->size);
             break;
    
    case 11: Kino_confess("can't set_postings");
             /* fall through */
    case 12: RETVAL = newRV_inc( (SV*)batch->postings );
             break;

    case 13: Kino_confess("can't set_tv_string");
             /* fall through */
    case 14: RETVAL = newSVsv(batch->tv_string);
             break;
    }
}
OUTPUT: RETVAL

=for comment

Proceed to the next item in the TokenBatch.  Returns true if the TokenBatch
ends up located at valid token.

=cut

bool
next(batch)
    TokenBatch *batch;
CODE:
    RETVAL = Kino_TokenBatch_next(batch);
OUTPUT: RETVAL

void
DESTROY(batch)
    TokenBatch *batch;
PPCODE:
    Kino_TokenBatch_destroy(batch);


__H__

#ifndef H_KINOSEARCH_ANALYSIS_TOKENBATCH
#define H_KINOSEARCH_ANALYSIS_TOKENBATCH 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "KinoSearchIndexTerm.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilMathUtils.h"
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
void Kino_TokenBatch_add_many_tokens(TokenBatch*, SV*, AV*, AV*);
U32 Kino_TokenBatch_next(TokenBatch*);
void Kino_TokenBatch_build_plist(TokenBatch*, U32, U16);

#endif /* include guard */

__C__

#include "KinoSearchAnalysisTokenBatch.h"

static void Kino_TokenBatch_do_add_token(TokenBatch*, char*, U32, U32);

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
    batch->tv_string    = &PL_sv_undef;
    batch->postings     = (AV*)&PL_sv_undef;

    return batch;
}


void
Kino_TokenBatch_destroy(TokenBatch *batch) {
    SvREFCNT_dec( (SV*)batch->texts );
    SvREFCNT_dec( (SV*)batch->postings );
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
Kino_TokenBatch_add_token(TokenBatch *batch, SV *token_text_sv, 
                          U32 start_offset, U32 end_offset) {
    char   *ptr;
    STRLEN  len;

    ptr = SvPV(token_text_sv, len);

    /* sanity check the offsets to make sure they're inside the SV */
    if (start_offset > len)
        Kino_confess("start_offset > len (%d > %"UVuf")", 
            start_offset, (UV) len);
    if (end_offset > len)
        Kino_confess("end_offset > len (%d > %"UVuf")", 
        end_offset, (UV)len);

    Kino_TokenBatch_do_add_token(batch, ptr, start_offset, end_offset);
}

static void
Kino_TokenBatch_do_add_token(TokenBatch *batch, char *ptr, U32 start_offset, 
                             U32 end_offset) {
    SV   *token_text_sv;
    int   i, max;
    char *scanning_ptr;

    /* make room for new tokens */
    if (batch->size >= batch->capacity) {
        batch->capacity += 100;
        av_extend(batch->texts, batch->capacity);
        Kino_Renew(batch->start_offsets, batch->capacity, U32);
        Kino_Renew(batch->end_offsets, batch->capacity, U32);
    }

    /* if a null byte is found, truncate the token text */
    max = end_offset - start_offset;
    scanning_ptr = ptr;
    for (i - 0; i < max; i++) {
        if (*scanning_ptr++ == '\0') {
            end_offset = start_offset + i;
            break;
        }
    }

    /* add the token to the batch */
    token_text_sv = newSVpvn( ptr, (end_offset - start_offset) );
    av_store(batch->texts, batch->size, token_text_sv);
    batch->start_offsets[ batch->size ] = start_offset;
    batch->end_offsets[ batch->size ]   = end_offset;
    batch->size++; 
}

void
Kino_TokenBatch_add_many_tokens(TokenBatch *batch, SV *string_sv, 
                                AV *starts_av, AV *ends_av) {
    char   *string_start;
    STRLEN  len, start_offset, end_offset;
    I32     i, j, max;
    SV    **start_sv_ptr;
    SV    **end_sv_ptr;

    string_start = SvPV(string_sv, len);

    max = av_len(starts_av);
    for (i = 0; i <= max; i++) {
        /* retrieve start */
        start_sv_ptr = av_fetch(starts_av, i, 0);
        if (start_sv_ptr == NULL)
            Kino_confess("Failed to retrieve array element");
        start_offset = SvIV(*start_sv_ptr);

        /* retrieve end */
        end_sv_ptr = av_fetch(ends_av, i, 0);
        if (end_sv_ptr == NULL)
            Kino_confess("Failed to retrieve array element");
        end_offset = SvIV(*end_sv_ptr);

        /* sanity check the offsets to make sure they're inside the string */
        if (start_offset > len)
            Kino_confess("start_offset > len (%d > %"UVuf")", 
                start_offset, (UV)len);
        if (end_offset > len)
            Kino_confess("end_offset > len (%d > %"UVuf")", 
                end_offset, (UV)len);

        /* calculate the start of the substring and add the token */
        Kino_TokenBatch_do_add_token(batch, (string_start + start_offset),
            start_offset, end_offset);
    }
}


#define POSDATA_LEN 12 
#define DOC_NUM_LEN 4
#define NULL_BYTE_LEN 1
#define TEXT_LEN_LEN 2

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
            len =   TEXT_LEN_LEN       /* for now, put text_len at top */
                  + KINO_FIELD_NUM_LEN /* encoded field number */
                  + text_len           /* term text */
                  + NULL_BYTE_LEN      /* the term text's null byte */
                  + DOC_NUM_LEN 
                  + POSDATA_LEN
                  + TEXT_LEN_LEN       /* eventually, text_len goes at end */
                  + NULL_BYTE_LEN;     /* the scalar's null byte */ 
            serialized_sv = newSV(len);
            SvPOK_on(serialized_sv);
            source_ptr = SvPVX(serialized_sv);
            dest_ptr   = source_ptr;

            /* concatenate a bunch of stuff onto the serialized scalar */
            Copy(text_len_buf, dest_ptr, TEXT_LEN_LEN, char);
            dest_ptr += TEXT_LEN_LEN;
            Copy(field_num_buf, dest_ptr, KINO_FIELD_NUM_LEN, char);
            dest_ptr += KINO_FIELD_NUM_LEN;
            Copy(text, dest_ptr, text_len + NULL_BYTE_LEN, char);
            dest_ptr += text_len + NULL_BYTE_LEN;
            Copy(doc_num_buf, dest_ptr, DOC_NUM_LEN, char);
            dest_ptr += DOC_NUM_LEN;
            SvCUR_set(serialized_sv, (dest_ptr - source_ptr)); 

            /* store the text => serialized_sv pair in the pos_hash */
            (void)hv_store_ent(pos_hash, text_sv, serialized_sv, 0); 
        }
        else {
            /* retrieve the serialized scalar and allocate more space */
            he = hv_fetch_ent(pos_hash, text_sv, 0, 0);
            serialized_sv = HeVAL(he);
            len = SvCUR(serialized_sv)
                + POSDATA_LEN    /* allocate space for upcoming posdata */
                + TEXT_LEN_LEN   /* extra space for encoded text length */
                + NULL_BYTE_LEN; 
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
        Copy(source_ptr, dest_ptr, TEXT_LEN_LEN, char);
        SvCUR(serialized_sv) += TEXT_LEN_LEN;
        source_ptr += TEXT_LEN_LEN;
        sv_chop(serialized_sv, source_ptr);

        SvREFCNT_inc(serialized_sv);
        av_store(out_av, i, serialized_sv);
        i++;
    }

    /* we're done with the positions hash, so kill it off */
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
        end_ptr = SvEND(serialized_sv) - TEXT_LEN_LEN;
        text_len = Kino_decode_bigend_U16( end_ptr );
        Kino_encode_bigend_U16(text_len, text_len_buf);

        source_ptr = SvPVX(serialized_sv) + 
            KINO_FIELD_NUM_LEN + text_len + NULL_BYTE_LEN + DOC_NUM_LEN;
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
                        - NULL_BYTE_LEN
                        - DOC_NUM_LEN 
                        - TEXT_LEN_LEN;
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
        Copy(text_len_buf, dest_ptr, TEXT_LEN_LEN, char);
        dest_ptr += TEXT_LEN_LEN;
        len = dest_ptr - SvPVX(serialized_sv);
        SvCUR_set(serialized_sv, len);

        last_text = text;
        last_len  = text_len;
    }
    
    /* store the postings array and the term vector string */
    SvREFCNT_dec(batch->tv_string);
    batch->tv_string = tv_string_sv;
    SvREFCNT_dec(batch->postings);
    batch->postings = out_av;
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Analysis::TokenBatch - a collection of tokens

=head1 DESCRIPTION

The TokenBatch would be an array of Tokens, if a Token class existed.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut


