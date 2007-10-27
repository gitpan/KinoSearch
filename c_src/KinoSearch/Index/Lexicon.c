#include <string.h>
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_LEXICON_VTABLE
#include "KinoSearch/Index/Lexicon.r"

#include "KinoSearch/Util/Carp.h"

bool_t 
Lex_next(Lexicon *self) 
{
    UNUSED_VAR(self);
    ABSTRACT_DEATH(self, "Next");
    UNREACHABLE_RETURN(bool_t);
}

void
Lex_seek(Lexicon *self, struct kino_Term *term) 
{
    UNUSED_VAR(term);
    ABSTRACT_DEATH(self, "Seek");
}

void 
Lex_reset(Lexicon *self) 
{
    ABSTRACT_DEATH(self, "Reset");
}

i32_t 
Lex_get_size(Lexicon *self) 
{
    ABSTRACT_DEATH(self, "Get_Size");
    UNREACHABLE_RETURN(i32_t);
}

i32_t 
Lex_get_term_num(Lexicon *self) 
{
    ABSTRACT_DEATH(self, "Get_Term_Num");
    UNREACHABLE_RETURN(i32_t);
}

struct kino_Term*
Lex_get_term(Lexicon *self) 
{
    ABSTRACT_DEATH(self, "Get_Term");
    UNREACHABLE_RETURN(struct kino_Term*);
}

struct kino_IntMap*
Lex_build_sort_cache(Lexicon *self, struct kino_PostingList *plist, 
                     u32_t max_doc)
{
    UNUSED_VAR(plist);
    UNUSED_VAR(max_doc);
    ABSTRACT_DEATH(self, "Build_Sort_Cache");
    UNREACHABLE_RETURN(struct kino_IntMap*);
}

void
Lex_seek_by_num(Lexicon *self, i32_t term_num)
{
    UNUSED_VAR(term_num);
    ABSTRACT_DEATH(self, "Seek_By_Num");
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

