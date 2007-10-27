#ifndef H_KINO_INDEXFILENAMES
#define H_KINO_INDEXFILENAMES 1

#include "charmony.h"

struct kino_ByteBuf;
struct kino_VArray;

/* Format constants for each sub-section of the InvIndex file format.  A
 * reader should be able to read anything up to and including the current
 * format.
 */
#define KINO_IXINFOS_FORMAT 1
#define KINO_SEG_INFOS_FORMAT 1
#define KINO_COMPOUND_FILE_FORMAT 1
#define KINO_DOC_STORAGE_FORMAT 1 
#define KINO_LEXICON_FORMAT 1
#define KINO_POSTING_LIST_FORMAT 1
#define KINO_DELDOCS_FORMAT 1

/* Constants related to locking. 
 */
#define KINO_READ_LOCK_TIMEOUT   1000
#define KINO_WRITE_LOCK_NAME     "write"
#define KINO_WRITE_LOCK_TIMEOUT  1000
#define KINO_COMMIT_LOCK_NAME    "commit"
#define KINO_COMMIT_LOCK_TIMEOUT 5000

#ifdef KINO_USE_SHORT_NAMES
  #define IXINFOS_FORMAT         KINO_IXINFOS_FORMAT
  #define SEG_INFOS_FORMAT       KINO_SEG_INFOS_FORMAT
  #define COMPOUND_FILE_FORMAT   KINO_COMPOUND_FILE_FORMAT
  #define DOC_STORAGE_FORMAT     KINO_DOC_STORAGE_FORMAT 
  #define LEXICON_FORMAT       KINO_LEXICON_FORMAT
  #define POSTING_LIST_FORMAT    KINO_POSTING_LIST_FORMAT
  #define DELDOCS_FORMAT         KINO_DELDOCS_FORMAT
#endif

/* Choose the latest generation filename matching [base] and [ext] from
 * amongst the supplied list of files.
 */
struct kino_ByteBuf*
kino_IxFileNames_latest_gen(struct kino_VArray *list, 
                            const struct kino_ByteBuf *base,
                            const struct kino_ByteBuf *ext);

/* Create a filename by encoding [gen] as base 36, then concatenating [base],
 * [gen], and [ext].
 */
struct kino_ByteBuf*
kino_IxFileNames_filename_from_gen(const struct kino_ByteBuf *base, 
                                   chy_i32_t gen, 
                                   const struct kino_ByteBuf *ext);

#ifdef KINO_USE_SHORT_NAMES
  #define IxFileNames_latest_gen         kino_IxFileNames_latest_gen 
  #define IxFileNames_filename_from_gen  kino_IxFileNames_filename_from_gen
#endif

#endif /* H_KINO_INDEXFILENAMES */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

