#define C_KINO_TOKENIZER
#define C_KINO_TOKEN
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Analysis/Tokenizer.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"

Tokenizer*
Tokenizer_new(const CharBuf *pattern)
{
    Tokenizer *self = (Tokenizer*)VTable_Make_Obj(TOKENIZER);
    return Tokenizer_init(self, pattern);
}

Inversion*
Tokenizer_transform(Tokenizer *self, Inversion *inversion)
{
    Inversion *new_inversion = Inversion_new(NULL);
    Token *token;

    while (NULL != (token = Inversion_Next(inversion))) {
        Tokenizer_Tokenize_Str(self, token->text, token->len, new_inversion);
    }

    return new_inversion;
}

Inversion*
Tokenizer_transform_text(Tokenizer *self, CharBuf *text)
{
    Inversion *new_inversion = Inversion_new(NULL);
    Tokenizer_Tokenize_Str(self, (char*)CB_Get_Ptr8(text), CB_Get_Size(text), 
        new_inversion);
    return new_inversion;
}

Obj*
Tokenizer_dump(Tokenizer *self)
{
    Tokenizer_dump_t super_dump
        = (Tokenizer_dump_t)SUPER_METHOD(TOKENIZER, Tokenizer, Dump);
    Hash *dump = (Hash*)ASSERT_IS_A(super_dump(self), HASH);
    Hash_Store_Str(dump, "pattern", 7, Obj_Dump(self->pattern));
    return (Obj*)dump;
}

Tokenizer*
Tokenizer_load(Tokenizer *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    Tokenizer_load_t super_load 
        = (Tokenizer_load_t)SUPER_METHOD(TOKENIZER, Tokenizer, Load);
    Tokenizer *loaded = super_load(self, dump);
    CharBuf *pattern = (CharBuf*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "pattern", 7), CHARBUF);
    return Tokenizer_init(loaded, pattern);
}

bool_t
Tokenizer_dump_equals(Tokenizer *self, Obj *dump)
{
    Tokenizer_dump_equals_t super_dump_equals = (Tokenizer_dump_equals_t)
        SUPER_METHOD(TOKENIZER, Tokenizer, Dump_Equals);
    if (!super_dump_equals(self, dump)) {
        return false;
    }
    else {
        Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
        CharBuf *pattern = (CharBuf*)Hash_Fetch_Str(source, "pattern", 7);
        if (!pattern) return false;
        if (!CB_Equals(self->pattern, (Obj*)pattern)) return false;
    }
    return true;
}

bool_t
Tokenizer_equals(Tokenizer *self, Obj *other)
{
    Tokenizer *const evil_twin = (Tokenizer*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, TOKENIZER)) return false;
    if (!CB_Equals(evil_twin->pattern, (Obj*)self->pattern)) return false;
    return true;
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

