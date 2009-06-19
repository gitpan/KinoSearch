#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Analysis/PolyAnalyzer.h"
#include "KinoSearch/Analysis/CaseFolder.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Analysis/Stemmer.h"
#include "KinoSearch/Analysis/Tokenizer.h"

PolyAnalyzer*
PolyAnalyzer_new(const CharBuf *language, VArray *analyzers)
{
    PolyAnalyzer *self = (PolyAnalyzer*)VTable_Make_Obj(&POLYANALYZER);
    return PolyAnalyzer_init(self, language, analyzers);
}

PolyAnalyzer*
PolyAnalyzer_init(PolyAnalyzer *self, const CharBuf *language, 
                  VArray *analyzers)
{
    Analyzer_init((Analyzer*)self);
    if (analyzers) {
        u32_t i, max;
        for (i = 0, max = VA_Get_Size(analyzers); i < max; i++) {
            ASSERT_IS_A(VA_Fetch(analyzers, i), ANALYZER);
        }
        self->analyzers = (VArray*)INCREF(analyzers);
    }
    else if (language) {
        self->analyzers = VA_new(3);
        VA_Push(self->analyzers, (Obj*)CaseFolder_new());
        VA_Push(self->analyzers, (Obj*)Tokenizer_new(NULL));
        VA_Push(self->analyzers, (Obj*)Stemmer_new(language));
    }
    else {
        THROW("Must specify either 'language' or 'analyzers'");
    }

    return self;
}

void
PolyAnalyzer_destroy(PolyAnalyzer *self)
{
    DECREF(self->analyzers);
    FREE_OBJ(self);
}

VArray*
PolyAnalyzer_get_analyzers(PolyAnalyzer *self) { return self->analyzers; }

Inversion*
PolyAnalyzer_transform(PolyAnalyzer *self, Inversion *inversion)
{
    VArray *const analyzers = self->analyzers;
    u32_t i, max;
    (void)INCREF(inversion);

    /* Iterate through each of the analyzers in order. */
    for (i = 0, max = VA_Get_Size(analyzers); i < max; i++) {
        Analyzer *analyzer = (Analyzer*)VA_Fetch(analyzers, i);
        Inversion *new_inversion = Analyzer_Transform(analyzer, inversion);
        DECREF(inversion);
        inversion = new_inversion;
    }

    return inversion;
}

Inversion*
PolyAnalyzer_transform_text(PolyAnalyzer *self, CharBuf *text)
{
    VArray *const analyzers     = self->analyzers;
    const   u32_t num_analyzers = VA_Get_Size(analyzers);
    Inversion    *retval;

    if (num_analyzers == 0) {
        size_t token_len = CB_Get_Size(text);
        Token *seed = Token_new(text->ptr, token_len, 0, token_len, 1.0f, 1);
        retval = Inversion_new(seed);
        DECREF(seed);
    }
    else {
        u32_t i;
        Analyzer *first_analyzer = (Analyzer*)VA_Fetch(analyzers, 0);
        retval = Analyzer_Transform_Text(first_analyzer, text);
        for (i = 1; i < num_analyzers; i++) {
            Analyzer *analyzer = (Analyzer*)VA_Fetch(analyzers, i);
            Inversion *new_inversion = Analyzer_Transform(analyzer, retval);
            DECREF(retval);
            retval = new_inversion;
        }
    }

    return retval;
}

bool_t
PolyAnalyzer_equals(PolyAnalyzer *self, Obj *other)
{
    PolyAnalyzer *const evil_twin = (PolyAnalyzer*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, POLYANALYZER)) return false;
    if (!VA_Equals(evil_twin->analyzers, (Obj*)self->analyzers)) return false;
    return true;
}

PolyAnalyzer*
PolyAnalyzer_load(PolyAnalyzer *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    PolyAnalyzer_load_t super_load 
        = (PolyAnalyzer_load_t)SUPER_METHOD(&POLYANALYZER, PolyAnalyzer, Load);
    PolyAnalyzer *loaded = super_load(self, dump);
    VArray *analyzer_dumps = (VArray*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "analyzers", 9), VARRAY);
    VArray *analyzers = (VArray*)ASSERT_IS_A(
        Obj_Load(analyzer_dumps, (Obj*)analyzer_dumps), VARRAY);
    PolyAnalyzer_init(loaded, NULL, analyzers);
    DECREF(analyzers);
    return loaded;
}

bool_t
PolyAnalyzer_dump_equals(PolyAnalyzer *self, Obj *dump)
{
    PolyAnalyzer_dump_equals_t super_dump_equals 
        = (PolyAnalyzer_dump_equals_t) SUPER_METHOD(&POLYANALYZER, 
            PolyAnalyzer, Dump_Equals);
    if (!super_dump_equals(self, dump)) { return false; }
    else {
        Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
        VArray *sub_dumps = (VArray*)Hash_Fetch_Str(source, "analyzers", 9);
        if (   !sub_dumps 
            || !OBJ_IS_A(sub_dumps, VARRAY)
            || VA_Get_Size(sub_dumps) != VA_Get_Size(self->analyzers)
        ) {
            return false;
        }
        else {
            u32_t i, max;
            for (i = 0, max = VA_Get_Size(sub_dumps); i < max; i++) {
                Obj *sub_dump = VA_Fetch(sub_dumps, i);
                Analyzer *sub_analyzer 
                    = (Analyzer*)VA_Fetch(self->analyzers, i);
                if (!Analyzer_Dump_Equals(sub_analyzer, sub_dump)) {
                    return false;
                }
            }
        }
    }

    return true;
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

