package KinoSearch::Index::PostingsWriter;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use File::Temp qw();
use File::Spec;
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::TermInfosWriter;
use KinoSearch::Util::SortExternal;

our %instance_vars = (
    # constructor params / members
    invindex => undef,
    seg_name => undef,

    # members
    sort_pool => undef,
);

sub init_instance {
    my $self = shift;

    # create a SortExternal object which autosorts the posting list cache
    $self->{sort_pool} = KinoSearch::Util::SortExternal->new(
        invindex => $self->{invindex},
        seg_name => $self->{seg_name},
    );
}

# Add all the postings in an inverted document to the sort pool.
sub add_postings {
    my ( $self, $postings_array ) = @_;
    $self->{sort_pool}->feed(@$postings_array);
}

# Bulk add all the postings in a segment to the sort pool.
sub add_segment {
    my ( $self, $seg_reader, $doc_map ) = @_;
    my $term_enum = $seg_reader->terms;
    my $term_docs = $seg_reader->term_docs;
    $term_docs->set_read_positions(1);
    _add_segment( $self->{sort_pool}, $term_enum, $term_docs, $doc_map );
}

=for comment

Process all the postings in the sort pool.  Generate the freqs and positions
files.  Hand off data to TermInfosWriter for the generating the term
dictionaries.

=cut

sub write_postings {
    my $self = shift;
    my ( $invindex, $seg_name ) = @{$self}{ 'invindex', 'seg_name' };

    $self->{sort_pool}->sort_all;

    my $tinfos_writer = KinoSearch::Index::TermInfosWriter->new(
        invindex => $invindex,
        seg_name => $seg_name,
    );
    my $frq_out = $invindex->open_outstream("$seg_name.frq");
    my $prx_out = $invindex->open_outstream("$seg_name.prx");

    _write_postings( $self->{sort_pool}, $tinfos_writer, $frq_out, $prx_out );

    $frq_out->close;
    $prx_out->close;
    $tinfos_writer->finish;
}

sub finish { }

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PostingsWriter      

void
_write_postings (sort_pool, tinfos_writer, frq_out, prx_out)
    SortExternal    *sort_pool;
    TermInfosWriter *tinfos_writer;
    OutStream       *frq_out;
    OutStream       *prx_out;
PPCODE:
    Kino_PostWriter_write_postings(sort_pool, tinfos_writer, frq_out,
        prx_out);

void
_add_segment(sort_pool, term_enum, term_docs, doc_map_ref)
    SortExternal  *sort_pool;
    SegTermEnum  *term_enum;
    TermDocs *term_docs;
    SV  *doc_map_ref;
PPCODE:
    Kino_PostWriter_add_segment(sort_pool, term_enum, term_docs, 
        doc_map_ref);

__H__

#ifndef H_KINOSEARCH_INDEX_POSTINGS_WRITER
#define H_KINOSEARCH_INDEX_POSTINGS_WRITER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchIndexSegTermEnum.h"
#include "KinoSearchIndexTerm.h"
#include "KinoSearchIndexTermDocs.h"
#include "KinoSearchIndexTermInfosWriter.h"
#include "KinoSearchStoreOutStream.h"
#include "KinoSearchUtilSortExternal.h"
#include "KinoSearchUtilStringHelper.h"

void Kino_PostWriter_write_postings(SortExternal*, TermInfosWriter*, 
                                    OutStream*, OutStream*);
void Kino_PostWriter_add_segment(SortExternal*, SegTermEnum*, TermDocs*, SV*);

#endif /* include guard */

__C__

#include "KinoSearchIndexPostingsWriter.h"

static void Kino_PostWriter_deserialize(SV*, SV*, U32*, U32*);
static void Kino_PostWriter_write_positions(OutStream*, SV*);

void
Kino_PostWriter_write_postings(SortExternal *sort_pool,
                               TermInfosWriter *tinfos_writer, 
                               OutStream *frq_out, OutStream *prx_out) {
    SV        *termstring_sv, *last_termstring_sv, *posting_sv, *scratch_sv;
    TermInfo  *tinfo;
    U32        doc_num;
    U32        freq;
    U32        last_doc_num      = 0;
    U32        last_skip_doc     = 0;
    double     frq_ptr, prx_ptr;
    double     last_skip_frq_ptr = 0.0;
    double     last_skip_prx_ptr = 0.0;
    I32        iter              = 0;
    I32        i, num_returned;
    AV        *skip_data_av;
    SV        *skip_sv;

    dSP;
    
    last_termstring_sv = newSVpvn("\0\0", 2);
    termstring_sv      = newSV(0);
    posting_sv         = newSV(0);
    tinfo              = Kino_TInfo_new();
    skip_data_av       = newAV();
    skip_sv            = &PL_sv_undef;

    /* each loop is one field, one term, one doc_num, many positions */
    while (1) {
        /* retrieve the next posting from the sort pool */
        scratch_sv = sort_pool->fetch(sort_pool);
        SvSetSV(posting_sv, scratch_sv);
        SvREFCNT_dec(scratch_sv);

        /* SortExternal returns undef when exhausted */
        if ( !SvOK(posting_sv) ) {
            goto FINAL_ITER;
        }

        /* each iter, add a doc to the doc_freq for a given term */
        iter++;
        tinfo->doc_freq++;    /* lags by 1 iter */

        /* Break up the serialized posting into its parts.
         * posting_sv gets whittled down until it is only the positions string.
         */
        Kino_PostWriter_deserialize(posting_sv, termstring_sv, 
            &doc_num, &freq);

        /* on the first iter, prime the "heldover" variables */
        if (iter == 1) {
            SvSetSV(last_termstring_sv, termstring_sv);
            tinfo->doc_freq      = 0;
            tinfo->frq_fileptr   = frq_out->tell(frq_out);
            tinfo->prx_fileptr   = prx_out->tell(prx_out);
            tinfo->skip_offset   = frq_out->tell(frq_out);
            tinfo->index_fileptr = 0;
        }
        else if ( iter == -1 ) { /* never true; can only get here via goto */
            /* prepare to clear out buffers and exit loop */
            FINAL_ITER: {
                iter = -1;
                sv_setpvn(termstring_sv, "\0\0", 2);
                tinfo->doc_freq++;
            }
        }

        /* create skipdata (unused by KinoSearch at present) */
        if ( (tinfo->doc_freq + 1) % tinfos_writer->skip_interval == 0 ) {
            frq_ptr = frq_out->tell(frq_out);
            prx_ptr = prx_out->tell(prx_out);

            av_push(skip_data_av, newSViv(last_doc_num - last_skip_doc    ));
            av_push(skip_data_av, newSViv(frq_ptr      - last_skip_frq_ptr));
            av_push(skip_data_av, newSViv(prx_ptr      - last_skip_prx_ptr));

            last_skip_doc     = last_doc_num;
            last_skip_frq_ptr = frq_ptr;
            last_skip_prx_ptr = prx_ptr;
        }

        /* if either the term or fieldnum changes, process the last term */
        if ( Kino_StrHelp_compare_svs(termstring_sv, last_termstring_sv) ) {
            /* take note of where we are for the term dictionary */
            frq_ptr = frq_out->tell(frq_out);
            prx_ptr = prx_out->tell(prx_out);

            /* write skipdata if there is any */
            if (av_len(skip_data_av) != -1) {
                /* kludge to compensate for doc_freq's 1-iter lag */
                if (
                    (tinfo->doc_freq + 1) % tinfos_writer->skip_interval == 0 
                ) {
                    /* remove 1 cycle of skip data */
                    for (i = 3; i > 0; i--) {
                        skip_sv = av_pop(skip_data_av);
                        SvREFCNT_dec(skip_sv);
                    }
                }
                if (av_len(skip_data_av) != -1) {
                    /* tell tinfos_writer about the non-zero skip amount */
                    tinfo->skip_offset = frq_ptr - tinfo->frq_fileptr;

                    /* write out the skip data */
                    i = av_len(skip_data_av);
                    while (i-- > -1) {
                        skip_sv = av_shift(skip_data_av);
                        frq_out->write_vint(frq_out, SvIV(skip_sv) );
                        SvREFCNT_dec(skip_sv);
                    }

                    /* update the filepointer for the file we just wrote to */
                    frq_ptr = frq_out->tell(frq_out);
                }
            }

            /* init skip data in preparation for the next term */
            last_skip_doc     = 0;
            last_skip_frq_ptr = frq_ptr;
            last_skip_prx_ptr = prx_ptr;

            /* hand off to TermInfosWriter */
            Kino_TInfosWriter_add(tinfos_writer, last_termstring_sv, tinfo);

            /* start each term afresh */
            tinfo->doc_freq      = 0;
            tinfo->frq_fileptr   = frq_ptr;
            tinfo->prx_fileptr   = prx_ptr;
            tinfo->skip_offset   = 0;
            tinfo->index_fileptr = 0;

            /* remember the termstring so we can write string diffs */
            SvSetSV(last_termstring_sv, termstring_sv);

            last_doc_num    = 0;
        }

        /* break out of loop on last iter before writing invalid data */
        if (iter == -1) {
            Kino_TInfo_destroy(tinfo);
            SvREFCNT_dec(posting_sv);
            SvREFCNT_dec(termstring_sv);
            SvREFCNT_dec(last_termstring_sv);
            SvREFCNT_dec( (SV*)skip_data_av );
            return;
        }

        /*  write positions data */
        Kino_PostWriter_write_positions(prx_out, posting_sv);

        /* write freq data */
        /* doc_code is delta doc_num, shifted left by 1. */
        if (freq == 1) {
            U32 doc_code = (doc_num - last_doc_num) << 1;
            /* set low bit of doc_code to 1 to indicate freq of 1 */
            doc_code += 1;
            frq_out->write_vint(frq_out, doc_code);
        }
        else {
            U32 doc_code = (doc_num - last_doc_num) << 1;
            /* leave low bit of doc_code at 0, record explicit freq */
            frq_out->write_vint(frq_out, doc_code);
            frq_out->write_vint(frq_out, freq);
        }

        /* remember last doc num because we need it for delta encoding */
        last_doc_num = doc_num;
    }
}

/* Pull apart a serialized posting into its component parts */

#define DOC_NUM_LEN 4
#define TEXT_LEN_LEN 2
#define NULL_BYTE_LEN 1 

void
Kino_PostWriter_add_segment(SortExternal *sort_pool, SegTermEnum* term_enum, 
                            TermDocs *term_docs, SV *doc_map_ref) {
    I32        *doc_map;
    I32         doc_num, max_doc;
    char        doc_num_buf[4];
    char        text_len_buf[4];
    SV         *posting_sv, *positions_sv, *doc_map_sv;
    TermBuffer *term_buf;
    STRLEN      len, common_len, positions_len;

    dSP;

    doc_map_sv = SvRV(doc_map_ref);
    doc_map    = (I32*)SvPV(doc_map_sv, len);
    max_doc = len / sizeof(I32);
    posting_sv = newSV(0);
    term_buf   = term_enum->term_buf;

    while (Kino_SegTermEnum_next(term_enum)) {
        /* start with the termstring and the null byte */
        Kino_encode_bigend_U16(term_buf->text_len, text_len_buf);
        common_len = term_buf->text_len + KINO_FIELD_NUM_LEN;
        sv_setpvn(posting_sv, term_buf->termstring, common_len);
        sv_catpvn(posting_sv, "\0", NULL_BYTE_LEN);
        common_len += NULL_BYTE_LEN;

        term_docs->seek_tinfo(term_docs, term_enum->tinfo);
        while (term_docs->next(term_docs)) {
            SvCUR_set(posting_sv, common_len);

            /* concat the remapped doc number */
            doc_num = term_docs->get_doc(term_docs);
            if (doc_num == -1)
                continue;
            if (doc_num > max_doc) 
                Kino_confess("doc_num > max_doc: %d %d", doc_num, max_doc);
            doc_num = doc_map[doc_num];
            Kino_encode_bigend_U32(doc_num, doc_num_buf);
            sv_catpvn(posting_sv, doc_num_buf, DOC_NUM_LEN); 

            /* concat the positions */
            positions_sv = term_docs->get_positions(term_docs);
            sv_catsv(posting_sv, positions_sv);

            /* concat the term_length */
            sv_catpvn(posting_sv, text_len_buf, TEXT_LEN_LEN);

            /* add the posting to the sortpool */
            sort_pool->feed(sort_pool, posting_sv);
        }
    }
}

static void 
Kino_PostWriter_deserialize(SV *posting_sv, SV *termstring_sv, 
                            U32 *doc_num_ptr, U32 *freq_ptr) {
    STRLEN   posting_len, termstring_len;
    char    *posting_str, *termstring_len_ptr;

    /* extract pointer from serialized posting */
    posting_str = SvPV(posting_sv, posting_len);

    /* extract termstring_len, decoding packed 'n', assign termstring */
    termstring_len_ptr = posting_str + posting_len - TEXT_LEN_LEN;
    termstring_len     
        = Kino_decode_bigend_U16(termstring_len_ptr) + KINO_FIELD_NUM_LEN;
    sv_setpvn(termstring_sv, posting_str, termstring_len);

    /* extract and assign doc_num, decoding packed 'N' */
    posting_str  += termstring_len + NULL_BYTE_LEN;
    *doc_num_ptr  = Kino_decode_bigend_U32(posting_str);
    posting_str  += DOC_NUM_LEN;

    /* whack encoded termstring_len off the end of the posting */
    posting_len -= TEXT_LEN_LEN; 
    SvCUR_set(posting_sv, posting_len);
    
    /* whack field_num/term text off the front, leaving only the positions */
    sv_chop(posting_sv, posting_str);

    /* calculate freq by counting the number of positions, assign */
    *freq_ptr = (posting_len - termstring_len - DOC_NUM_LEN) / 4;
}

/* Write out the positions data using delta encoding.
 */
static void
Kino_PostWriter_write_positions(OutStream* prx_outstream, SV* positions_sv) {
    STRLEN   positions_len;
    char    *positions;
    U32     *current_pos_ptr;
    U32     *end;
    U32      last_pos;
    U32      pos_delta;

    positions = SvPV(positions_sv, positions_len);

    /* extract 32 bit unsigned integers from positions_sv.  */
    current_pos_ptr = (U32*)positions;
    end             = current_pos_ptr + (positions_len / 4);
    last_pos        = 0;
    while (current_pos_ptr < end) {
        /* get delta and write out as VInt */
        pos_delta = *current_pos_ptr - last_pos;
        prx_outstream->write_vint(prx_outstream, pos_delta);

        /* advance pointers */
        last_pos = *current_pos_ptr;
        current_pos_ptr++;
    }
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::PostingsWriter - write postings data to an invindex

=head1 DESCRIPTION

PostingsWriter creates posting lists.  It writes the frequency and and
positional data files, plus feeds data to TermInfosWriter.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut

