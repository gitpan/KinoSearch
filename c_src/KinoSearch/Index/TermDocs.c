#include <string.h>

#define KINO_USE_SHORT_NAMES

#define KINO_WANT_TERMDOCS_VTABLE
#include "KinoSearch/Index/TermDocs.r"

#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermList.r"
#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

void
TermDocs_set_doc_freq(TermDocs *self, u32_t doc_freq) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(doc_freq);
    CONFESS("TermDocs_Set_Doc_Freq must be defined in a subclass");
}

u32_t
TermDocs_get_doc_freq(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Doc_Freq must be defined in a subclass");
    UNREACHABLE_RETURN(u32_t);
}

u32_t
TermDocs_get_doc(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Doc must be defined in a subclass");
    UNREACHABLE_RETURN(u32_t);
}

u32_t
TermDocs_get_freq(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Freq must be defined in a subclass");
    UNREACHABLE_RETURN(u32_t);
}

u8_t
TermDocs_get_field_boost_byte(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Field_Boost_Byte must be defined in a subclass");
    UNREACHABLE_RETURN(u8_t);
}

ByteBuf*
TermDocs_get_positions(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Positions must be defined in a subclass");
    UNREACHABLE_RETURN(ByteBuf*);
}

ByteBuf*
TermDocs_get_boosts(TermDocs *self)
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Get_Boosts must be defined in a subclass");
    UNREACHABLE_RETURN(ByteBuf*);
}

void
TermDocs_seek(TermDocs *self, Term *target) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(target);
    CONFESS("TermDocs_Seek must be defined in a subclass");
}

void
TermDocs_seek_tl(TermDocs *self, TermList *term_list) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(term_list);
    CONFESS("TermDocs_Seek_TL must be defined in a subclass");
}

bool_t
TermDocs_next(TermDocs *self) 
{
    UNUSED_VAR(self);
    CONFESS("TermDocs_Next must be defined in a subclass");
    UNREACHABLE_RETURN(bool_t);
}

u32_t  
TermDocs_bulk_read(TermDocs* self, ByteBuf *doc_nums_bb, 
                   ByteBuf *field_boosts_bb, ByteBuf *freqs_bb, 
                   ByteBuf *prox_bb, ByteBuf *boosts_bb, u32_t num_wanted) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(doc_nums_bb);
    UNUSED_VAR(field_boosts_bb);
    UNUSED_VAR(freqs_bb);
    UNUSED_VAR(prox_bb);
    UNUSED_VAR(boosts_bb);
    UNUSED_VAR(num_wanted);
    CONFESS("TermDocs_Bulk_Read must be defined in a subclass");
    UNREACHABLE_RETURN(u32_t);
}

bool_t
TermDocs_skip_to(TermDocs *self, u32_t target) 
{
    do {
        if ( !TermDocs_Next(self) )
            return false;
    } while (target > TermDocs_Get_Doc(self));
    return true;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

