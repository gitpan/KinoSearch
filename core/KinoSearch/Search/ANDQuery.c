#define C_KINO_ANDQUERY
#define C_KINO_ANDCOMPILER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/ANDQuery.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/ANDScorer.h"
#include "KinoSearch/Search/Searcher.h"
#include "KinoSearch/Search/Span.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Freezer.h"

ANDQuery*
ANDQuery_new(VArray *children)
{
    ANDQuery *self = (ANDQuery*)VTable_Make_Obj(ANDQUERY);
    return ANDQuery_init(self, children);
}

ANDQuery*
ANDQuery_init(ANDQuery *self, VArray *children)
{
    return (ANDQuery*)PolyQuery_init((PolyQuery*)self, children);
}

CharBuf*
ANDQuery_to_string(ANDQuery *self)
{
    uint32_t num_kids = VA_Get_Size(self->children);
    if (!num_kids) return CB_new_from_trusted_utf8("()", 2);
    else {
        CharBuf *retval = CB_new_from_trusted_utf8("(", 1);
        uint32_t i;
        for (i = 0; i < num_kids; i++) {
            CharBuf *kid_string = Obj_To_String(VA_Fetch(self->children, i));
            CB_Cat(retval, kid_string);
            DECREF(kid_string);
            if (i == num_kids - 1) {
                CB_Cat_Trusted_Str(retval, ")", 1);
            }
            else {
                CB_Cat_Trusted_Str(retval, " AND ", 5);
            }
        }
        return retval;
    }
}


bool_t
ANDQuery_equals(ANDQuery *self, Obj *other)
{
    if ((ANDQuery*)other == self) return true;
    if (!Obj_Is_A(other, ANDQUERY)) { return false; }
    return PolyQuery_equals((PolyQuery*)self, other);
}

Compiler*
ANDQuery_make_compiler(ANDQuery *self, Searcher *searcher, float boost)
{
    return (Compiler*)ANDCompiler_new(self, searcher, boost);
}

/**********************************************************************/

ANDCompiler*
ANDCompiler_new(ANDQuery *parent, Searcher *searcher, float boost)
{
    ANDCompiler *self = (ANDCompiler*)VTable_Make_Obj(ANDCOMPILER);
    return ANDCompiler_init(self, parent, searcher, boost);
}

ANDCompiler*
ANDCompiler_init(ANDCompiler *self, ANDQuery *parent, Searcher *searcher, 
                 float boost)
{
    PolyCompiler_init((PolyCompiler*)self, (PolyQuery*)parent, searcher, 
        boost);
    ANDCompiler_Normalize(self);
    return self;
}

Matcher*
ANDCompiler_make_matcher(ANDCompiler *self, SegReader *reader, 
                         bool_t need_score)
{
    uint32_t num_kids = VA_Get_Size(self->children);

    if (num_kids == 1) {
        Compiler *only_child = (Compiler*)VA_Fetch(self->children, 0);
        return Compiler_Make_Matcher(only_child, reader, need_score);
    }
    else {
        uint32_t i;
        VArray *child_matchers = VA_new(num_kids);

        // Add child matchers one by one. 
        for (i = 0; i < num_kids; i++) {
            Compiler *child = (Compiler*)VA_Fetch(self->children, i);
            Matcher *child_matcher 
                = Compiler_Make_Matcher(child, reader, need_score);

            // If any required clause fails, the whole thing fails. 
            if (child_matcher == NULL) {
                DECREF(child_matchers);
                return NULL;
            }
            else {
                VA_Push(child_matchers, (Obj*)child_matcher);
            }
        }

        { 
            Matcher *retval = (Matcher*)ANDScorer_new(child_matchers, 
                ANDCompiler_Get_Similarity(self));
            DECREF(child_matchers);
            return retval;
        }
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

