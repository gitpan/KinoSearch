#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_PRESORTER_VTABLE
#include "KinoSearch/Index/PreSorter.r"

#include "KinoSearch/Index/SegLexicon.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Util/IntMap.r"

/* MSort compare ops.
 */
static int
compare_docs_by_field_vals(void *context, const void *va, const void *vb);
static int
reverse_compare_docs_by_field_vals(void *context, const void *va, 
                                  const void *vb);

PreSorter*
PreSorter_new(const ByteBuf *field, bool_t reverse)
{
    CREATE(self, PreSorter, PRESORTER);

    /* assign */
    self->field = BB_CLONE(field);
    self->reverse = reverse;

    /* init */
    self->vals      = Hash_new(0);
    self->doc_vals  = VA_new(0);
    self->doc_remap = IntMap_new(NULL, 0);
    self->scratch   = BB_new(0);

    self->compare   = reverse ? reverse_compare_docs_by_field_vals
                              : compare_docs_by_field_vals;
    return self;
}

void
PreSorter_destroy(PreSorter *self)
{
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->vals);
    REFCOUNT_DEC(self->doc_vals);
    REFCOUNT_DEC(self->doc_remap);
    REFCOUNT_DEC(self->scratch);
    free(self);
}

void
PreSorter_add_val(PreSorter *self, u32_t doc_num, const ByteBuf *val)
{
    VArray  *doc_vals = self->doc_vals;
    ByteBuf *kept_val = Hash_Add_Key(self->vals, val);
    if (doc_num != doc_vals->size)
        CONFESS("Out of sequence: %u != %u + 1", doc_num, doc_vals->size);
    VA_Push(doc_vals, (Obj*)kept_val);
}

void
PreSorter_add_seg_data(PreSorter *self, u32_t seg_max_doc, 
                       SegLexicon *lexicon, IntMap *sort_cache, 
                       IntMap *seg_doc_remap)
{
    VArray *all_term_texts = VA_new(seg_max_doc);
    u32_t i;

    /* accumulate all term texts in an array for fast access */
    while (SegLex_Next(lexicon)) {
        Term *term = SegLex_Get_Term(lexicon);
        ByteBuf *term_text = BB_CLONE(term->text);
        VA_Push(all_term_texts, (Obj*)term_text);
        REFCOUNT_DEC(term_text);
    }
    if (all_term_texts->size < seg_max_doc)
        CONFESS("Not enough terms: %u %u", all_term_texts->size, seg_max_doc);

    for (i = 0; i < seg_max_doc; i++) {
        i32_t new_doc_num = seg_doc_remap == NULL 
            ? i 
            : IntMap_Get(seg_doc_remap, i);
        if (new_doc_num != -1) {
            i32_t term_num = IntMap_Get(sort_cache, i);
            if (term_num == -1) {
                CONFESS("Document number with no term: %u", new_doc_num);
            }
            else {
                ByteBuf *term_text 
                    = (ByteBuf*)VA_Fetch(all_term_texts, term_num);
                PreSorter_Add_Val(self, new_doc_num, term_text);
            }
        }
    }

    /* clean up */
    REFCOUNT_DEC(all_term_texts);
}

IntMap*
kino_PreSorter_gen_remap(kino_PreSorter *self)
{
    VArray  *doc_vals      = self->doc_vals;
    IntMap  *doc_remap     = self->doc_remap;
    ByteBuf *scratch       = self->scratch;
    const i32_t total_docs = doc_vals->size;
    const i32_t old_docs   = doc_remap->size;
    const i32_t new_docs   = doc_vals->size - old_docs;
    i32_t *sorted, *ints;
    i32_t i;

    /* don't redo sort unless we've added more docs */
    if (new_docs == 0)
        return doc_remap;

    /* grow remap, scratch to accomodate new docs */
    BB_GROW(scratch, doc_vals->size * sizeof(i32_t));
    sorted = (i32_t*)scratch->ptr;
    for (i = 0; i < total_docs; i++) {
        sorted[i] = i;
    }
    doc_remap->ints = REALLOCATE(doc_remap->ints, total_docs, i32_t);
    ints            = doc_remap->ints;
    doc_remap->size = total_docs;

    /* sort to the scratch, then apply reverse to map */
    MSort_mergesort(sorted, ints, total_docs,
        self->compare, doc_vals);
    for (i = 0; i < total_docs; i++) {
        ints[sorted[i]] = i;
    }

    return doc_remap;
}

static int
compare_docs_by_field_vals(void *context, const void *va, const void *vb)
{
    const i32_t doc_num_a = *(i32_t*)va;
    const i32_t doc_num_b = *(i32_t*)vb;
    VArray *const doc_vals = (VArray*)context;
    ByteBuf *const val_a = (ByteBuf*)VA_Fetch(doc_vals, doc_num_a);
    ByteBuf *const val_b = (ByteBuf*)VA_Fetch(doc_vals, doc_num_b);
    int comparison = BB_compare(&val_a, &val_b);

    /* break ties by doc_num */
    if (comparison == 0) 
        comparison = doc_num_a - doc_num_b;

    return comparison;
}

static int
reverse_compare_docs_by_field_vals(void *context, const void *va, 
                                  const void *vb)
{
    const i32_t doc_num_a = *(i32_t*)va;
    const i32_t doc_num_b = *(i32_t*)vb;
    VArray *const doc_vals = (VArray*)context;
    ByteBuf *const val_a = (ByteBuf*)VA_Fetch(doc_vals, doc_num_a);
    ByteBuf *const val_b = (ByteBuf*)VA_Fetch(doc_vals, doc_num_b);
    int comparison = 0 - BB_compare(&val_a, &val_b); /* the only change */

    /* break ties by doc_num */
    if (comparison == 0) 
        comparison = doc_num_a - doc_num_b;

    return comparison;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

