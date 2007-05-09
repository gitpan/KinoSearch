#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MULTILEXICON_VTABLE
#include "KinoSearch/Index/MultiLexicon.r"

#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Index/SegLexicon.r"
#include "KinoSearch/Index/LexCache.r"
#include "KinoSearch/Util/PriorityQueue.r"
#include "KinoSearch/Util/IntMap.r"

/* No-op for speed.  We'll handle destruction of queue elements via destroy. 
 */
static void
free_q_elem(void *elem);

/* Compare SegLexicons.
 */
static bool_t
lex_less_than(const void *a, const void *b);

MultiLexicon*
MultiLex_new(const ByteBuf *field, VArray *seg_lexicons, LexCache *lex_cache)
{
    CREATE(self, MultiLexicon, MULTILEXICON);

    /* sanity check */
    if (seg_lexicons->size == 0)
        CONFESS("No SegLexicons");

    /* init */
    self->term_num        = -1;
    self->term            = NULL;
    self->lex_q = PriQ_new(seg_lexicons->size, lex_less_than, free_q_elem);

    /* assign */
    REFCOUNT_INC(seg_lexicons);
    if (lex_cache != NULL)
        REFCOUNT_INC(lex_cache);
    self->lex_cache       = lex_cache;
    self->seg_lexicons    = seg_lexicons;
    self->field           = BB_CLONE(field);

    MultiLex_Reset(self);

    return self;
}

void
MultiLex_destroy(MultiLexicon *self)
{
    REFCOUNT_DEC(self->seg_lexicons);
    REFCOUNT_DEC(self->lex_q);
    REFCOUNT_DEC(self->lex_cache);
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->term);
    free(self);
}

void
MultiLex_reset(MultiLexicon *self)
{
    u32_t i;
    VArray *seg_lexicons = self->seg_lexicons;
    PriorityQueue *lex_q  = self->lex_q;

    /* empty out the queue */
    while ( PriQ_Pop(lex_q) != NULL) { }

    /* fill the queue with valid SegLexicons */
    for (i = 0; i < seg_lexicons->size; i++) {
        SegLexicon *const seg_lexicon 
            = (SegLexicon*)VA_Fetch(seg_lexicons, i);
        SegLex_Reset(seg_lexicon);
        if (SegLex_Next(seg_lexicon)) {
            PriQ_Insert(self->lex_q, seg_lexicon);
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
MultiLex_next(MultiLexicon *self)
{
    PriorityQueue *lex_q   = self->lex_q;
    SegLexicon *top_seg_lexicon = PriQ_Peek(lex_q);
    Term *term;
    ByteBuf *term_text;
    
    /* if queue is empty, iterator is finished */
    if (top_seg_lexicon == NULL) {
        REFCOUNT_DEC(self->term);
        self->term = NULL;
        return false;
    }

    /* increment term num (even if it's not valid) */
    self->term_num++;

    /* copy the top item's term */
    term = SegLex_Get_Term(top_seg_lexicon); 
    if (self->term == NULL)
        self->term = (Term*)Term_Clone(term);
    else 
        BB_Copy_BB(self->term->text, term->text);

    /* churn through queue items with equal terms */
    term_text = self->term->text;
    while (top_seg_lexicon != NULL) {
        Term *const candidate = SegLex_Get_Term(top_seg_lexicon); 
        if ( BB_compare( &term_text, &(candidate->text) ) != 0 ) {
            /* bail if the next item in the queue has a different term */
            break;
        }
        else {
            PriQ_Pop(lex_q);
            if (SegLex_Next(top_seg_lexicon)) {
                PriQ_Insert(lex_q, top_seg_lexicon);
            }
            top_seg_lexicon = PriQ_Peek(lex_q);
        }
    }

    return true;
}

IntMap*
MultiLex_build_sort_cache(MultiLexicon *self, PostingList *plist, 
                          u32_t max_doc)
{
    i32_t *ints = MALLOCATE(max_doc, i32_t);
    i32_t num_index_terms = 0;
    ByteBuf *last_term_text =  BB_new(0);
    ByteBuf **term_texts;
    i32_t i;
    i32_t index_interval;
    SegLexicon *seg_lexicon;
    
    for (i = 0; i < max_doc; i++) {
        ints[i] = -1;
    }

    /* use index interval from one of the sub lexicons */
    seg_lexicon = (SegLexicon*)VA_Fetch(self->seg_lexicons, 0);
    index_interval = seg_lexicon->index_interval;

    /* allocate enough space for the cache texts in worst case */
    term_texts  = MALLOCATE(((max_doc / index_interval) + 1), ByteBuf*);
    term_texts[num_index_terms++] = BB_CLONE(last_term_text);

    MultiLex_Reset(self);

    while (MultiLex_Next(self)) {
        Term *const term = MultiLex_Get_Term(self);

        /* build cache of term texts */
        if (self->term_num + 1 % index_interval == 0 && self->term_num != 0) {
            term_texts[ num_index_terms++ ] = BB_CLONE(last_term_text);
            BB_Copy_BB(last_term_text, term->text);
        }
            
        /* build sort cache */
        PList_Seek(plist, term);
        while (PList_Next(plist)) {
            ints[ PList_Get_Doc_Num(plist) ] = self->term_num;
        }
    }

    term_texts = REALLOCATE(term_texts, num_index_terms, ByteBuf*);
    REFCOUNT_DEC(self->lex_cache);
    self->lex_cache = LexCache_new(self->field, term_texts, 
        num_index_terms, index_interval);

    /* clean up */
    REFCOUNT_DEC(last_term_text);

    return IntMap_new(ints, max_doc);
}

void
MultiLex_seek(MultiLexicon *self, Term *target)
{
    u32_t i;
    VArray *seg_lexicons = self->seg_lexicons;
    PriorityQueue *lex_q = self->lex_q;
    Term *temp_target;
    ByteBuf *current_text;

    if (self->lex_cache == NULL) {
        char *term_text = target == NULL ? "" : target->text->ptr;
        CONFESS("Can't seek to '%s' unless cache is filled", term_text);
    }

    /* seek the cache and set vars */
    LexCache_Seek(self->lex_cache, target);
    self->term_num = LexCache_Get_Term_Num(self->lex_cache);
    temp_target = LexCache_Get_Term(self->lex_cache);
    if (self->term == NULL)
        self->term = (Term*)Term_Clone(temp_target);
    else 
        BB_Copy_BB(self->term->text, temp_target->text);

    /* empty out the queue */
    while ( PriQ_Pop(lex_q) != NULL) { }

    /* refill the queue */
    for (i = 0; i < seg_lexicons->size; i++) {
        SegLexicon *const seg_lexicon 
            = (SegLexicon*)VA_Fetch(seg_lexicons, i);
        SegLex_Seek(seg_lexicon, temp_target);
        if (SegLex_Get_Term(seg_lexicon) != NULL)
            PriQ_Insert(self->lex_q, seg_lexicon);
    }

    /* scan up to the real target */
    current_text = self->term->text;
    do {
        const i32_t comparison = BB_compare(&current_text, &(target->text));
        if ( comparison >= 0 &&  self->term_num != -1) {
            break;
        }
    } while (MultiLex_Next(self));
}

i32_t 
MultiLex_get_term_num(MultiLexicon *self)
{
    if (self->lex_cache == NULL)
        CONFESS("term num is invalid unless cache filled");
    return self->term_num;
}

Term* 
MultiLex_get_term(MultiLexicon *self)
{
    return self->term;
}

static void
free_q_elem(void *elem)
{
    UNUSED_VAR(elem);
}

static bool_t
lex_less_than(const void *va, const void *vb)
{
    SegLexicon *const a  = (SegLexicon*)va;
    SegLexicon *const b  = (SegLexicon*)vb;
    Term *const term_a = SegLex_Get_Term(a);
    Term *const term_b = SegLex_Get_Term(b);
    return BB_less_than(&(term_a->text), &(term_b->text));
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

