#include <string.h>

#define KINO_USE_SHORT_NAMES

#define KINO_WANT_TERMLIST_VTABLE
#include "KinoSearch/Index/TermList.r"

#include "KinoSearch/Util/Carp.h"

bool_t 
TermList_next(TermList *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermList_Next must be defined in a subclass");
    UNREACHABLE_RETURN(bool_t);
}

void
TermList_seek(TermList *self, struct kino_Term *term) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(term);
    CONFESS("TermList_Seek must be defined in a subclass");
}

void 
TermList_reset(TermList *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermList_Reset must be defined in a subclass");
}

i32_t 
TermList_get_term_num(TermList *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermList_Get_Term_Num must be defined in a subclass");
    UNREACHABLE_RETURN(i32_t);
}

struct kino_Term*
TermList_get_term(TermList *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermList_Get_Term must be defined in a subclass");
    UNREACHABLE_RETURN(struct kino_Term*);
}

struct kino_IntMap*
TermList_build_sort_cache(TermList *self, struct kino_TermDocs *term_docs, 
                          kino_u32_t max_doc)
{
    UNUSED_VAR(self);
    UNUSED_VAR(term_docs);
    UNUSED_VAR(max_doc);
    CONFESS("TermList_Build_Sort_Cache must be defined in a subclass");
    UNREACHABLE_RETURN(struct kino_IntMap*);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

