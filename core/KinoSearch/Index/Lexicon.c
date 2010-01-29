#define C_KINO_LEXICON
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/Lexicon.h"

Lexicon*
Lex_init(Lexicon *self)
{
    self->field = NULL;
    ABSTRACT_CLASS_CHECK(self, LEXICON);
    return self;
}

CharBuf*
Lex_get_field(Lexicon *self) { return self->field; }

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

