#define C_KINO_ORQUERY
#define C_KINO_ORCOMPILER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/ORQuery.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Search/ORMatcher.h"
#include "KinoSearch/Search/Searcher.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

ORQuery*
ORQuery_new(VArray *children)
{
    ORQuery *self = (ORQuery*)VTable_Make_Obj(ORQUERY);
    return ORQuery_init(self, children);
}

ORQuery*
ORQuery_init(ORQuery *self, VArray *children)
{
    return (ORQuery*)PolyQuery_init((PolyQuery*)self, children);
}

Compiler*
ORQuery_make_compiler(ORQuery *self, Searcher *searcher, float boost)
{
    return (Compiler*)ORCompiler_new(self, searcher, boost);
}

bool_t
ORQuery_equals(ORQuery *self, Obj *other)
{
    if ((ORQuery*)other == self)   { return true;  }
    if (!Obj_Is_A(other, ORQUERY)) { return false; }
    return PolyQuery_equals((PolyQuery*)self, other);
}

CharBuf*
ORQuery_to_string(ORQuery *self)
{
    uint32_t num_kids = VA_Get_Size(self->children);
    if (!num_kids) return CB_new_from_trusted_utf8("()", 2);
    else {
        CharBuf *retval = CB_new_from_trusted_utf8("(", 1);
        uint32_t i;
        uint32_t last_kid = num_kids - 1;
        for (i = 0; i < num_kids; i++) {
            CharBuf *kid_string = Obj_To_String(VA_Fetch(self->children, i));
            CB_Cat(retval, kid_string);
            DECREF(kid_string);
            if (i == last_kid) {
                CB_Cat_Trusted_Str(retval, ")", 1);
            }
            else {
                CB_Cat_Trusted_Str(retval, " OR ", 4);
            }
        }
        return retval;
    }
}

/**********************************************************************/

ORCompiler*
ORCompiler_new(ORQuery *parent, Searcher *searcher, float boost)
{
    ORCompiler *self = (ORCompiler*)VTable_Make_Obj(ORCOMPILER);
    return ORCompiler_init(self, parent, searcher, boost);
}

ORCompiler*
ORCompiler_init(ORCompiler *self, ORQuery *parent, Searcher *searcher, 
                 float boost)
{
    PolyCompiler_init((PolyCompiler*)self, (PolyQuery*)parent, searcher, 
        boost);
    ORCompiler_Normalize(self);
    return self;
}

Matcher*
ORCompiler_make_matcher(ORCompiler *self, SegReader *reader, 
                        bool_t need_score)
{
    uint32_t num_kids = VA_Get_Size(self->children);

    if (num_kids == 1) {
        Compiler *only_child = (Compiler*)VA_Fetch(self->children, 0);
        return Compiler_Make_Matcher(only_child, reader, need_score);
    }
    else {
        VArray *submatchers = VA_new(num_kids);
        uint32_t i;
        uint32_t num_submatchers = 0;

        // Accumulate sub-matchers. 
        for (i = 0; i < num_kids; i++) {
            Compiler *child = (Compiler*)VA_Fetch(self->children, i);
            Matcher *submatcher 
                = Compiler_Make_Matcher(child, reader, need_score);
            if (submatcher != NULL) {
                VA_Push(submatchers, (Obj*)submatcher);
                num_submatchers++;
            }
        }

        if (num_submatchers == 0) {
            // No possible matches, so return null. 
            DECREF(submatchers);
            return NULL;
        }
        else if (num_submatchers == 1) {
            // Only one submatcher, so no need for ORScorer wrapper. 
            Matcher *submatcher = (Matcher*)INCREF(VA_Fetch(submatchers, 0));
            DECREF(submatchers);
            return submatcher;
        }
        else {
            Similarity *sim    = ORCompiler_Get_Similarity(self);
            Matcher    *retval = need_score
                ? (Matcher*)ORScorer_new(submatchers, sim)
                : (Matcher*)ORMatcher_new(submatchers);
            DECREF(submatchers);
            return retval;
        }
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

