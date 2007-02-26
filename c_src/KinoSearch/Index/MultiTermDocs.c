#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MULTITERMDOCS_VTABLE
#include "KinoSearch/Index/MultiTermDocs.r"

#include "KinoSearch/Index/Term.r"

MultiTermDocs*
MultiTermDocs_new(u32_t num_subs, TermDocs **sub_term_docs, u32_t *starts)
{
    u32_t i;
    CREATE(self, MultiTermDocs, MULTITERMDOCS);

    /* init */
    self->num_subs        = 0;
    self->base            = 0;
    self->pointer         = 0;
    self->starts          = NULL;
    self->sub_term_docs   = NULL;
    self->current         = NULL;
    
    /* assign */
    self->num_subs      = num_subs;
    self->sub_term_docs = sub_term_docs;
    self->starts        = starts;
        
    /* manage refcounts */
    for (i = 0; i < num_subs; i++) {
        REFCOUNT_INC(sub_term_docs[i]);
    }

    return self;
}

void
MultiTermDocs_destroy(MultiTermDocs* self) 
{
    u32_t i;
    TermDocs **sub_term_docs = self->sub_term_docs;

    for (i = 0; i < self->num_subs; i++) {
        REFCOUNT_DEC(sub_term_docs[i]);
    }

    free(self->sub_term_docs);
    free(self->starts);

    free(self);
}

void
MultiTermDocs_seek(MultiTermDocs *self, Term *target)
{
    u32_t i;
    for (i = 0; i < self->num_subs; i++) {
        TermDocs *const sub_td = self->sub_term_docs[i];
        TermDocs_Seek(sub_td, target);
    }
    self->base     = 0;
    self->pointer  = 0;
    self->current  = NULL;
}

void
MultiTermDocs_set_doc_freq(MultiTermDocs *self, u32_t doc_freq) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(doc_freq);
    CONFESS("can't set doc_freq on a MultiTermDocs");
}

u32_t
MultiTermDocs_get_doc_freq(MultiTermDocs *self) 
{
    u32_t i;
    u32_t doc_freq = 0;

    /* sum the doc_freqs of all segments */
    for (i = 0; i < self->num_subs; i++) {
        TermDocs *const sub_td = self->sub_term_docs[i];
        doc_freq += TermDocs_Get_Doc_Freq(sub_td);
    }
    return doc_freq;
}

u32_t 
MultiTermDocs_get_doc(MultiTermDocs *self) 
{
    if (self->current == NULL) 
        return KINO_TERM_DOCS_SENTINEL;

    return TermDocs_Get_Doc(self->current) + self->base;
}

u32_t
MultiTermDocs_get_freq(MultiTermDocs *self) 
{
    if (self->current == NULL) 
        return KINO_TERM_DOCS_SENTINEL;

    return TermDocs_Get_Freq(self->current);
}

u8_t 
MultiTermDocs_get_field_boost_byte(MultiTermDocs *self)
{
    if (self->current == NULL) 
        return 0;

    return TermDocs_Get_Field_Boost_Byte(self->current);
}

ByteBuf*
MultiTermDocs_get_positions(MultiTermDocs *self) 
{
    if (self->current == NULL) 
        return NULL;

    return TermDocs_Get_Positions(self->current);
}

ByteBuf*
MultiTermDocs_get_boosts(MultiTermDocs *self) 
{
    if (self->current == NULL) 
        return NULL;

    return TermDocs_Get_Boosts(self->current);
}

u32_t
MultiTermDocs_bulk_read(MultiTermDocs *self, ByteBuf *doc_nums_bb, 
                        ByteBuf *field_boosts_bb, ByteBuf *freqs_bb, 
                        ByteBuf *prox_bb, ByteBuf *boosts_bb, u32_t num_wanted)
{
    while (1) {
        /* move to the next SegTermDocs */
        u32_t num_got;
        while (self->current == NULL) {
            if (self->pointer < self->num_subs) {
                self->base = self->starts[ self->pointer ];
                self->current = self->sub_term_docs[ self->pointer ];
                self->pointer++;
            }
            else {
                return 0;
            }
        }
        
        num_got = TermDocs_Bulk_Read( self->current, doc_nums_bb,
            field_boosts_bb, freqs_bb, prox_bb, boosts_bb, num_wanted );

        if (num_got == 0) {
            /* no more docs left in this segment */
            self->current = NULL;
        }
        else {
            /* add the start offset for this seg to each doc */
            const u32_t base = self->base;
            u32_t *doc_nums  = (u32_t*)doc_nums_bb->ptr;
            u32_t i;

            for (i = 0; i < num_got; i++) {
                *doc_nums++ += base;
            }

            return num_got;
        }
    }
}

bool_t
MultiTermDocs_next(MultiTermDocs* self) 
{
    while (1) {
        if (self->current != NULL && TermDocs_Next(self->current) ) {
            return true;
        }
        else if (self->pointer < self->num_subs) {
            /* try next segment */
            self->base    = self->starts[ self->pointer ];
            self->current = self->sub_term_docs[ self->pointer ];
            self->pointer++;
        }
        else {
            /* done with all segments */
            return false;
        }
    }
}

bool_t 
MultiTermDocs_skip_to(MultiTermDocs *self, u32_t target)
{
    while (1) {
        if (   self->current != NULL 
            && TermDocs_Skip_To(self->current, (target - self->base))
        ) {
            return true;
        }
        else if (self->pointer < self->num_subs) {
            /* try next segment */
            self->base    = self->starts[ self->pointer ];
            self->current = self->sub_term_docs[ self->pointer ];
            self->pointer++;
        }
        else {
            return false;
        }
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

