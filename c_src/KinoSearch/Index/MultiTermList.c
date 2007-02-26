#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MULTITERMLIST_VTABLE
#include "KinoSearch/Index/MultiTermList.r"

#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermDocs.r"
#include "KinoSearch/Index/SegTermList.r"
#include "KinoSearch/Index/TermListCache.r"
#include "KinoSearch/Util/PriorityQueue.r"
#include "KinoSearch/Util/IntMap.r"

/* No-op for speed.  We'll handle destruction of queue elements via destroy. 
 */
static void
free_q_elem(void *elem);

/* Compare terms */
static bool_t
tl_less_than(const void *a, const void *b);

MultiTermList*
MultiTermList_new(const ByteBuf *field, VArray *seg_term_lists, 
                  TermListCache *tl_cache)
{
    CREATE(self, MultiTermList, MULTITERMLIST);

    /* init */
    self->term_num        = -1;
    self->term            = NULL;
    self->list_q = PriQ_new(seg_term_lists->size, tl_less_than, free_q_elem);

    /* assign */
    REFCOUNT_INC(seg_term_lists);
    if (tl_cache != NULL)
        REFCOUNT_INC(tl_cache);
    self->tl_cache        = tl_cache;
    self->seg_term_lists  = seg_term_lists;
    self->field           = BB_CLONE(field);

    MultiTermList_Reset(self);

    return self;
}

void
MultiTermList_destroy(MultiTermList *self)
{
    REFCOUNT_DEC(self->seg_term_lists);
    REFCOUNT_DEC(self->list_q);
    REFCOUNT_DEC(self->tl_cache);
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->term);
    free(self);
}

void
MultiTermList_reset(MultiTermList *self)
{
    u32_t i;
    VArray *seg_term_lists = self->seg_term_lists;
    PriorityQueue *list_q  = self->list_q;

    /* empty out the queue */
    while ( PriQ_Pop(list_q) != NULL) { }

    /* fill the queue with valid SegTermLists */
    for (i = 0; i < seg_term_lists->size; i++) {
        SegTermList *const seg_tl = (SegTermList*)VA_Fetch(seg_term_lists, i);
        SegTermList_Reset(seg_tl);
        if (SegTermList_Next(seg_tl)) {
            PriQ_Insert(self->list_q, seg_tl);
        }
    }

    /* reset vars */
    if (self->term != NULL) {
        REFCOUNT_DEC(self->term);
        self->term = NULL;
    }
    self->term_num = -1;
}

bool_t
MultiTermList_next(MultiTermList *self)
{
    PriorityQueue *list_q    = self->list_q;
    SegTermList *top_seg_tl = PriQ_Peek(list_q);
    Term *term;
    ByteBuf *term_text;
    
    /* if queue is empty, iterator is finished */
    if (top_seg_tl == NULL) {
        REFCOUNT_DEC(self->term);
        self->term = NULL;
        return false;
    }

    /* increment term num (even if it's not valid) */
    self->term_num++;

    /* copy the top item's term */
    term = SegTermList_Get_Term(top_seg_tl); 
    if (self->term == NULL)
        self->term = (Term*)Term_Clone(term);
    else 
        BB_Copy_BB(self->term->text, term->text);

    /* churn through queue items with equal terms */
    term_text = self->term->text;
    while (top_seg_tl != NULL) {
        Term *const candidate = SegTermList_Get_Term(top_seg_tl); 
        if ( BB_compare( &term_text, &(candidate->text) ) != 0 ) {
            /* bail if the next item in the queue has a different term */
            break;
        }
        else {
            PriQ_Pop(list_q);
            if (SegTermList_Next(top_seg_tl)) {
                PriQ_Insert(list_q, top_seg_tl);
            }
            top_seg_tl = PriQ_Peek(list_q);
        }
    }

    return true;
}

IntMap*
MultiTermList_build_sort_cache(MultiTermList *self, TermDocs *term_docs, 
                               u32_t max_doc)
{
    i32_t *ints = CALLOCATE(max_doc, i32_t);
    i32_t num_index_terms = 0;
    ByteBuf **term_texts  = MALLOCATE(((max_doc / 16) + 1), ByteBuf*);
    ByteBuf *last_term_text =  BB_new(0);

    MultiTermList_Reset(self);

    while (MultiTermList_Next(self)) {
        Term *const term = MultiTermList_Get_Term(self);

        /* build cache of term texts */
        if (self->term_num % 16 == 0 && self->term_num > 0) {
            term_texts[ num_index_terms++ ] = BB_CLONE(last_term_text);
            BB_Copy_BB(last_term_text, term->text);
        }
            
        /* build sort cache */
        TermDocs_Seek(term_docs, term);
        while (TermDocs_Next(term_docs)) {
            ints[ TermDocs_Get_Doc(term_docs) ] = self->term_num;
        }
    }

    term_texts = REALLOCATE(term_texts, num_index_terms, ByteBuf*);
    REFCOUNT_DEC(self->tl_cache);
    self->tl_cache = TLCache_new(self->field, term_texts, num_index_terms, 16);

    /* clean up */
    REFCOUNT_DEC(last_term_text);

    return IntMap_new(ints, max_doc);
}

void
MultiTermList_seek(MultiTermList *self, Term *target)
{
    u32_t i;
    VArray *seg_term_lists = self->seg_term_lists;
    PriorityQueue *list_q  = self->list_q;
    Term *temp_target;
    ByteBuf *current_text;

    if (self->tl_cache == NULL) {
        char *term_text = target == NULL ? "" : target->text->ptr;
        CONFESS("Can't seek to '%s' unless cache is filled", term_text);
    }

    /* seek the cache and set vars */
    TLCache_Seek(self->tl_cache, target);
    self->term_num = TLCache_Get_Term_Num(self->tl_cache);
    temp_target = TLCache_Get_Term(self->tl_cache);
    if (self->term == NULL)
        self->term = (Term*)Term_Clone(temp_target);
    else 
        BB_Copy_BB(self->term->text, temp_target->text);

    /* empty out the queue */
    while ( PriQ_Pop(list_q) != NULL) { }

    /* refill the queue */
    for (i = 0; i < seg_term_lists->size; i++) {
        SegTermList *const seg_tl = (SegTermList*)VA_Fetch(seg_term_lists, i);
        SegTermList_Seek(seg_tl, temp_target);
        if (SegTermList_Get_Term(seg_tl) != NULL)
            PriQ_Insert(self->list_q, seg_tl);
    }

    /* scan up to the real target */
    current_text = self->term->text;
    do {
        const i32_t comparison = BB_compare(&current_text, &(target->text));
        if ( comparison >= 0 &&  self->term_num != -1) {
            break;
        }
    } while (MultiTermList_Next(self));
}

i32_t 
MultiTermList_get_term_num(MultiTermList *self)
{
    if (self->tl_cache == NULL)
        CONFESS("term num is invalid unless cache filled");
    return self->term_num;
}

Term* 
MultiTermList_get_term(MultiTermList *self)
{
    return self->term;
}

static void
free_q_elem(void *elem)
{
    UNUSED_VAR(elem);
}

static bool_t
tl_less_than(const void *va, const void *vb)
{
    SegTermList *const a  = (SegTermList*)va;
    SegTermList *const b  = (SegTermList*)vb;
    Term *const term_a = SegTermList_Get_Term(a);
    Term *const term_b = SegTermList_Get_Term(b);
    return BB_less_than(&(term_a->text), &(term_b->text));
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

