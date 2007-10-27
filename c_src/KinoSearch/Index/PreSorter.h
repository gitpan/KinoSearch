#ifndef H_KINO_PRESORTER
#define H_KINO_PRESORTER 1

#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/MSort.h"

/** 
 * @class KinoSearch::Index::PreSorter PreSorter.r
 * @brief Pre-sort docs indexed docs within a segment.
 * 
 * Pre-sorter is used to facilitate the pre-sorting of documents within a
 * segment according to their values for a given field.
 */

struct kino_SegLexicon;

typedef struct kino_PreSorter kino_PreSorter;
typedef struct KINO_PRESORTER_VTABLE KINO_PRESORTER_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::PreSorter", "PreSorter", 
    "KinoSearch::Util::Obj");

struct kino_PreSorter {
    KINO_PRESORTER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_ByteBuf   *field;
    chy_bool_t             reverse;
    kino_MSort_compare_t   compare;
    struct kino_Hash      *vals;
    struct kino_VArray    *doc_vals;
    struct kino_IntMap    *doc_remap;
    struct kino_ByteBuf   *scratch;
};

/* Constructor.
 */
kino_PreSorter*
kino_PreSorter_new(const struct kino_ByteBuf *field, chy_bool_t reverse);

/* Add a provisional_doc_num => value pair.
 */
void
kino_PreSorter_add_val(kino_PreSorter *self, chy_u32_t doc_num, 
                       const struct kino_ByteBuf *val);
KINO_METHOD("Kino_PreSorter_Add_Val");

void
kino_PreSorter_add_seg_data(kino_PreSorter *self, chy_u32_t seg_max_doc,
                            struct kino_SegLexicon *lexicon,
                            struct kino_IntMap *sort_cache,
                            struct kino_IntMap *seg_doc_remap);
KINO_METHOD("Kino_PreSorter_Add_Seg_Data");

/* Build/rebuild a remapping of document numbers, sorted by pre-sort field
 * value.  Returns [self->doc_remap].
 */
struct kino_IntMap*
kino_PreSorter_gen_remap(kino_PreSorter *self);
KINO_METHOD("Kino_PreSorter_Gen_Remap");

void
kino_PreSorter_destroy(kino_PreSorter *self);
KINO_METHOD("Kino_PreSorter_Destroy");

KINO_END_CLASS

#endif /* H_KINO_PRESORTER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

