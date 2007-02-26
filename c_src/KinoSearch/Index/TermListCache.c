#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMLISTCACHE_VTABLE
#include "KinoSearch/Index/TermListCache.r"

#include "KinoSearch/Index/Term.r"

TermListCache*
TLCache_new(ByteBuf *field, ByteBuf **term_texts, i32_t size, 
            i32_t index_interval)
{
    ByteBuf empty = BYTEBUF_BLANK;
    CREATE(self, TermListCache, TERMLISTCACHE);

    /* init */
    self->tick = 0;

    /* assign */
    self->field           = BB_CLONE(field);
    self->size            = size;
    self->index_interval  = index_interval;
    self->term_texts      = term_texts;

    /* derive */
    self->term              = Term_new(field, &empty);

    return self;
}

void
TLCache_destroy(TermListCache *self) 
{    
    i32_t       i;
    ByteBuf   **term_texts = self->term_texts;

    /* free term_texts cache */
    for (i = 0; i < self->size; i++) {
        REFCOUNT_DEC(term_texts[i]);
    }
    free(term_texts);

    /* kill off members */
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->term);

    /* last, the object itself */
    free(self);
}

i32_t
TLCache_get_term_num(TermListCache *self)
{
    return (self->index_interval * self->tick) - 1;
}

Term*
TLCache_get_term(TermListCache *self)
{
    BB_Copy_BB(self->term->text, self->term_texts[ self->tick ] );
    return self->term;
}

void
TLCache_seek(TermListCache *self, Term *term)
{
    ByteBuf    **term_texts = self->term_texts;
    ByteBuf     *target_text;
    i32_t        lo     = 0;
    i32_t        hi     = self->size - 1;
    i32_t        result = -100;

    if (term == NULL)
        return;
    else
        target_text = term->text;

    /* divide and conquer */
    while (hi >= lo) {
        const i32_t mid = (lo + hi) >> 1;
        const i32_t comparison = BB_compare(&target_text, &(term_texts[mid]));

        if (comparison < 0) {
            hi = mid - 1;
        }
        else if (comparison > 0) {
            lo = mid + 1;
        }
        else {
            result = mid;
            break;
        }
    }

    /* record the index of the entry we've seeked to */
    self->tick = hi == -1   ? 0  /* indicating that target lt first entry */
           : result == -100 ? hi /* if result is still -100, it wasn't set */
           : result;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

