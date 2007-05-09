#ifndef H_KINO_RAWPOSTING
#define H_KINO_RAWPOSTING 1

#include "KinoSearch/Posting.r"

/** 
 * @class KinoSearch::Posting::RawPosting RawPosting.r
 * @brief Sortable, serialized Posting.
 * 
 * RawPosting is a specialized subclass of Posting for private use only.  It
 * is used at index-time for fast reading, writing, sorting and merging of
 * index posting data by PostingPool.
 * 
 * RawPosting's Destroy method throws an error.  All RawPosting objects belong
 * to a particular MemoryPool, which takes responsibility for freeing them.  
 * 
 * The last struct member, [blob], is a "flexible array" member.  RawPosting
 * objects are assigned one continuous memory block of variable size,
 * depending on how much data needs to fit in blob. 
 * 
 * The first part of blob is the term's text content, the length of which is
 * indicated by [content_len].  At the end of the content, encoded auxilliary
 * posting information begins, ready to be blasted out verbatim to a postings
 * file once the after the doc num is written.
 */

typedef struct kino_RawPosting kino_RawPosting;
typedef struct KINO_RAWPOSTING_VTABLE KINO_RAWPOSTING_VTABLE;

KINO_CLASS("KinoSearch::Index::RawPosting", "RawPost", 
    "KinoSearch::Util::Obj");

struct kino_RawPosting {
    KINO_RAWPOSTING_VTABLE *_;
    KINO_POSTING_MEMBER_VARS;
    chy_u32_t     freq;
    chy_u32_t     content_len;
    chy_u32_t     aux_len;
    char          blob[1]; /* flexible array */
};

/* Constructor.  Uses pre-allocated memory.
 */
kino_RawPosting*
kino_RawPost_new(void *pre_allocated_memory, chy_u32_t doc_num, 
                 chy_u32_t freq, char *term_text, size_t term_text_len);

/* Write the posting's doc num and auxilliary content to the outstream.
 */
void
kino_RawPost_write_record(kino_RawPosting *self, 
                          struct kino_OutStream *outstream, 
                          chy_u32_t last_doc_num);
KINO_METHOD("Kino_RawPost_Write_Record");

/* Throws an error.
 */
void
kino_RawPost_destroy();
KINO_METHOD("Kino_RawPost_Destroy");

KINO_END_CLASS

extern kino_RawPosting KINO_RAWPOSTING_BLANK;

#ifdef KINO_USE_SHORT_NAMES
  #define RAWPOSTING_BLANK         KINO_RAWPOSTING_BLANK
#endif

#endif /* H_KINO_RAWPOSTING */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

