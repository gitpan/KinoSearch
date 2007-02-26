#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_DOCVECTOR_VTABLE
#include "KinoSearch/Index/DocVector.h"

#include "KinoSearch/Store/InStream.r"

HV* 
kino_DocVec_extract_tv_cache(SV *tv_string_sv) 
{
    HV            *tv_cache_hv = newHV();
    STRLEN         tv_len;
    char          *tv_string = SvPV(tv_string_sv, tv_len);
    char         **tv_ptr    = &tv_string;
    kino_i32_t     num_terms = kino_InStream_decode_vint(tv_ptr);
    SV            *text_sv = newSV(1);
    kino_i32_t     i;
    
    /* create a base text scalar */
    SvPOK_on(text_sv);
    SvUTF8_on(text_sv);
    *(SvEND(text_sv)) = '\0';

    /* read the number of vectorized terms in the field */
    for (i = 0; i < num_terms; i++) {
        char         *bookmark_ptr;
        SV           *nums_sv;
        STRLEN        overlap = kino_InStream_decode_vint(tv_ptr);
        STRLEN        len = kino_InStream_decode_vint(tv_ptr);
        kino_i32_t    num_positions;

        /* decompress the term text */
        SvCUR_set(text_sv, overlap);
        sv_catpvn(text_sv, *tv_ptr, len);
        *tv_ptr += len;

        /* get positions & offsets string */
        num_positions = kino_InStream_decode_vint(tv_ptr);
        bookmark_ptr = *tv_ptr;
        while(num_positions--) {
            /* leave nums compressed to save a little mem */
            (void)kino_InStream_decode_vint(tv_ptr);
            (void)kino_InStream_decode_vint(tv_ptr);
            (void)kino_InStream_decode_vint(tv_ptr);
        }
        len = *tv_ptr - bookmark_ptr;
        nums_sv = newSVpvn(bookmark_ptr, len);

        /* store the $text => $posdata pair in the output hash */
        hv_store_ent(tv_cache_hv, text_sv, nums_sv, 0);
    }
    SvREFCNT_dec(text_sv);

    return tv_cache_hv;
}

void
kino_DocVec_extract_posdata(SV *posdata_sv, AV *positions_av, AV *starts_av,  
                            AV *ends_av) 
{
    STRLEN  len;
    char   *posdata     = SvPV(posdata_sv, len);
    char   *posdata_end = SvEND(posdata_sv);
    char  **posdata_ptr = &posdata;

    /* translate encoded VInts to Perl scalars */
    while(*posdata_ptr < posdata_end) {
        SV *num_sv = newSViv( kino_InStream_decode_vint(posdata_ptr) );
        av_push(positions_av, num_sv);
        num_sv = newSViv( kino_InStream_decode_vint(posdata_ptr) );
        av_push(starts_av,    num_sv);
        num_sv = newSViv( kino_InStream_decode_vint(posdata_ptr) );
        av_push(ends_av,      num_sv);
    }

    if (*posdata_ptr != posdata_end)
        KINO_CONFESS("Bad encoding of posdata");
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

