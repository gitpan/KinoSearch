#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Analysis/Stemmer.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"

Stemmer_sb_stemmer_new_t    Stemmer_sb_stemmer_new    = NULL;
Stemmer_sb_stemmer_delete_t Stemmer_sb_stemmer_delete = NULL;
Stemmer_sb_stemmer_stem_t   Stemmer_sb_stemmer_stem   = NULL;
Stemmer_sb_stemmer_length_t Stemmer_sb_stemmer_length = NULL;

Stemmer*
Stemmer_new(const CharBuf *language)
{
    Stemmer *self = (Stemmer*)VTable_Make_Obj(STEMMER);
    return Stemmer_init(self, language);
}

Stemmer*
Stemmer_init(Stemmer *self, const CharBuf *language)
{
    char lang_buf[3];
    Analyzer_init((Analyzer*)self);
    self->language = CB_Clone(language);

    /* Get a Snowball stemmer.  Be case-insensitive. */
    Stemmer_load_snowball();
    lang_buf[0] = tolower(CB_Code_Point_At(language, 0));
    lang_buf[1] = tolower(CB_Code_Point_At(language, 1));
    lang_buf[2] = '\0';
    self->snowstemmer = kino_Stemmer_sb_stemmer_new(lang_buf, "UTF_8");
    if (!self->snowstemmer) 
        THROW(ERR, "Can't find a Snowball stemmer for %o", language);

    return self;
}

void
Stemmer_destroy(Stemmer *self)
{
    if (self->snowstemmer) kino_Stemmer_sb_stemmer_delete(self->snowstemmer);
    DECREF(self->language);
    FREE_OBJ(self);
}

Inversion*
Stemmer_transform(Stemmer *self, Inversion *inversion)
{
    Token *token;
    struct sb_stemmer *const snowstemmer = self->snowstemmer;

    while (NULL != (token = Inversion_Next(inversion))) {
        sb_symbol *stemmed_text = kino_Stemmer_sb_stemmer_stem(snowstemmer, 
            (sb_symbol*)token->text, token->len);
        size_t len = kino_Stemmer_sb_stemmer_length(snowstemmer);
        if (len > token->len) {
            FREEMEM(token->text);
            token->text = MALLOCATE(len + 1, char);
        }
        memcpy(token->text, stemmed_text, len + 1);
        token->len = len;
    }
    Inversion_Reset(inversion);
    return (Inversion*)INCREF(inversion);
}

Hash*
Stemmer_dump(Stemmer *self)
{
    Stemmer_dump_t super_dump 
        = (Stemmer_dump_t)SUPER_METHOD(STEMMER, Stemmer, Dump);
    Hash *dump = super_dump(self);
    Hash_Store_Str(dump, "language", 8, (Obj*)CB_Clone(self->language));
    return dump;
}

Stemmer*
Stemmer_load(Stemmer *self, Obj *dump)
{
    Stemmer_load_t super_load 
        = (Stemmer_load_t)SUPER_METHOD(STEMMER, Stemmer, Load);
    Stemmer *loaded = super_load(self, dump);
    Hash    *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *language = (CharBuf*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "language", 8), CHARBUF);
    return Stemmer_init(loaded, language);
}

bool_t
Stemmer_equals(Stemmer *self, Obj *other)
{
    Stemmer *const evil_twin = (Stemmer*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, STEMMER)) return false;
    if (!CB_Equals(evil_twin->language, (Obj*)self->language)) return false;
    return true;
} 

bool_t
Stemmer_dump_equals(Stemmer *self, Obj *dump)
{
    Stemmer_dump_equals_t super_dump_equals 
        = (Stemmer_dump_equals_t)SUPER_METHOD(STEMMER, Stemmer, Dump_Equals);
    if (!super_dump_equals(self, dump)) {
        return false;
    }
    else {
        Hash *const source = (Hash*)ASSERT_IS_A(dump, HASH);
        CharBuf *language  = (CharBuf*)Hash_Fetch_Str(source, "language", 8);
        if (!language) return false;
        if (!CB_Equals(self->language, (Obj*)language)) {
            return false;
        }
    }
    return true;
} 

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

