#define C_KINO_RANGEQUERY
#define C_KINO_RANGECOMPILER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/RangeQuery.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/RangeScorer.h"
#include "KinoSearch/Search/Searcher.h"
#include "KinoSearch/Search/Span.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Freezer.h"

// Determine the lowest ordinal that should match. 
static int32_t
S_find_lower_bound(RangeCompiler *self, SortCache *sort_cache);

// Determine the highest ordinal that should match. 
static int32_t
S_find_upper_bound(RangeCompiler *self, SortCache *sort_cache);

RangeQuery*
RangeQuery_new(const CharBuf *field, Obj *lower_term, Obj *upper_term,
               bool_t include_lower, bool_t include_upper)
{
    RangeQuery *self = (RangeQuery*)VTable_Make_Obj(RANGEQUERY);
    return RangeQuery_init(self, field, lower_term, upper_term, 
        include_lower, include_upper);
}

RangeQuery*
RangeQuery_init(RangeQuery *self, const CharBuf *field, Obj *lower_term,
                Obj *upper_term, bool_t include_lower, bool_t include_upper)
{
    Query_init((Query*)self, 0.0f);
    self->field          = CB_Clone(field);
    self->lower_term     = lower_term ? Obj_Clone(lower_term) : NULL;
    self->upper_term     = upper_term ? Obj_Clone(upper_term) : NULL;
    self->include_lower  = include_lower;
    self->include_upper  = include_upper;
    if (!upper_term && !lower_term) {
        DECREF(self);
        self = NULL;
        THROW(ERR, "Must supply at least one of 'upper_term' and 'lower_term'");
    }
    return self;
}

void
RangeQuery_destroy(RangeQuery *self)
{
    DECREF(self->field);
    DECREF(self->lower_term);
    DECREF(self->upper_term);
    SUPER_DESTROY(self, RANGEQUERY);
}

bool_t
RangeQuery_equals(RangeQuery *self, Obj *other)
{
    RangeQuery *evil_twin = (RangeQuery*)other;
    if (evil_twin == self) return true;
    if (!Obj_Is_A(other, RANGEQUERY)) return false;
    if (self->boost != evil_twin->boost) return false;
    if (!CB_Equals(self->field, (Obj*)evil_twin->field)) return false;
    if (self->lower_term && !evil_twin->lower_term) return false;
    if (self->upper_term && !evil_twin->upper_term) return false;
    if (!self->lower_term && evil_twin->lower_term) return false;
    if (!self->upper_term && evil_twin->upper_term) return false;
    if (   self->lower_term 
        && !Obj_Equals(self->lower_term, evil_twin->lower_term)) return false;
    if (   self->upper_term 
        && !Obj_Equals(self->upper_term, evil_twin->upper_term)) return false;
    if (self->include_lower != evil_twin->include_lower) return false;
    if (self->include_upper != evil_twin->include_upper) return false;
    return true;
}

CharBuf*
RangeQuery_to_string(RangeQuery *self)
{
    CharBuf *lower_term_str = self->lower_term 
                            ? Obj_To_String(self->lower_term)
                            : CB_new_from_trusted_utf8("*", 1);
    CharBuf *upper_term_str = self->upper_term 
                            ? Obj_To_String(self->upper_term)
                            : CB_new_from_trusted_utf8("*", 1);
    CharBuf *retval = CB_newf("%o:%s%o TO %o%s", self->field,
        self->include_lower ? "[" : "{",
        lower_term_str,
        upper_term_str,
        self->include_upper ? "]" : "}"
    );
    DECREF(upper_term_str);
    DECREF(lower_term_str);
    return retval;
}

void
RangeQuery_serialize(RangeQuery *self, OutStream *outstream)
{
    OutStream_Write_F32(outstream, self->boost);
    CB_Serialize(self->field, outstream);
    if (self->lower_term) {
        OutStream_Write_U8(outstream, true);
        FREEZE(self->lower_term, outstream);
    }
    else {
        OutStream_Write_U8(outstream, false);
    }
    if (self->upper_term) {
        OutStream_Write_U8(outstream, true);
        FREEZE(self->upper_term, outstream);
    }
    else {
        OutStream_Write_U8(outstream, false);
    }
    OutStream_Write_U8(outstream, self->include_lower);
    OutStream_Write_U8(outstream, self->include_upper);
}

RangeQuery*
RangeQuery_deserialize(RangeQuery *self, InStream *instream)
{
    // Deserialize components. 
    float boost     = InStream_Read_F32(instream);
    CharBuf *field  = CB_deserialize(NULL, instream);
    Obj *lower_term = InStream_Read_U8(instream) ? THAW(instream) : NULL;
    Obj *upper_term = InStream_Read_U8(instream) ? THAW(instream) : NULL;
    bool_t include_lower = InStream_Read_U8(instream);
    bool_t include_upper = InStream_Read_U8(instream);

    // Init object. 
    self = self ? self : (RangeQuery*)VTable_Make_Obj(RANGEQUERY);
    RangeQuery_init(self, field, lower_term, upper_term, include_lower,
        include_upper);
    RangeQuery_Set_Boost(self, boost);

    DECREF(upper_term);
    DECREF(lower_term);
    DECREF(field);
    return self;
}

RangeCompiler*
RangeQuery_make_compiler(RangeQuery *self, Searcher *searcher, 
                         float boost)
{
    return RangeCompiler_new(self, searcher, boost);
}

/**********************************************************************/

RangeCompiler*
RangeCompiler_new(RangeQuery *parent, Searcher *searcher, float boost)
{
    RangeCompiler *self 
        = (RangeCompiler*)VTable_Make_Obj(RANGECOMPILER);
    return RangeCompiler_init(self, parent, searcher, boost);
}

RangeCompiler*
RangeCompiler_init(RangeCompiler *self, RangeQuery *parent, 
                   Searcher *searcher, float boost)
{
    return (RangeCompiler*)Compiler_init((Compiler*)self, (Query*)parent, 
        searcher, NULL, boost);
}

RangeCompiler*
RangeCompiler_deserialize(RangeCompiler *self, InStream *instream)
{
    self = self ? self : (RangeCompiler*)VTable_Make_Obj(RANGECOMPILER);
    return (RangeCompiler*)Compiler_deserialize((Compiler*)self, instream);
}

Matcher*
RangeCompiler_make_matcher(RangeCompiler *self, SegReader *reader,
                           bool_t need_score)
{
    RangeQuery *parent = (RangeQuery*)self->parent;
    SortReader *sort_reader 
        = (SortReader*)SegReader_Fetch(reader, VTable_Get_Name(SORTREADER));
    SortCache *sort_cache = sort_reader
        ? SortReader_Fetch_Sort_Cache(sort_reader, parent->field) 
        : NULL;
    UNUSED_VAR(need_score);

    if (!sort_cache) {
        return NULL;
    }
    else {
        int32_t lower = S_find_lower_bound(self, sort_cache);
        int32_t upper = S_find_upper_bound(self, sort_cache);
        int32_t max_ord = SortCache_Get_Cardinality(sort_cache) + 1;
        if (lower > max_ord || upper < 0) {
            return NULL;
        }
        else {
            int32_t doc_max = SegReader_Doc_Max(reader);
            return (Matcher*)RangeScorer_new(lower, upper, sort_cache, 
                doc_max);
        }
    }
}

static int32_t
S_find_lower_bound(RangeCompiler *self, SortCache *sort_cache)
{
    RangeQuery *parent      = (RangeQuery*)self->parent;
    Obj        *lower_term  = parent->lower_term;
    int32_t     lower_bound = 0;

    if (lower_term) {
        int32_t low_ord = SortCache_Find(sort_cache, lower_term);
        if (low_ord < 0) {
            // The supplied term is lower than all terms in the field. 
            lower_bound = 0;
        }
        else {
            Obj *value = SortCache_Make_Blank(sort_cache);
            Obj *low_found = SortCache_Value(sort_cache, low_ord, value);
            bool_t exact_match = low_found == NULL
                               ? false
                               : Obj_Equals(lower_term, low_found);

            lower_bound = low_ord;
            if (!exact_match || !parent->include_lower) {
                lower_bound++;
            }
            DECREF(value);
        }
    }

    return lower_bound;
}

static int32_t
S_find_upper_bound(RangeCompiler *self, SortCache *sort_cache)
{
    RangeQuery *parent     = (RangeQuery*)self->parent;
    Obj        *upper_term = parent->upper_term;
    int32_t     retval     = I32_MAX;

    if (upper_term) {
        int32_t hi_ord = SortCache_Find(sort_cache, upper_term);
        if (hi_ord < 0) {
            // The supplied term is lower than all terms in the field. 
            retval = -1;
        }
        else {
            Obj *value = SortCache_Make_Blank(sort_cache);
            Obj *hi_found = SortCache_Value(sort_cache, hi_ord, value);
            bool_t exact_match = hi_found == NULL
                               ? false
                               : Obj_Equals(upper_term, (Obj*)hi_found);

            retval = hi_ord;
            if (exact_match && !parent->include_upper) {
                retval--;
            }
            DECREF(value);
        }
    }

    return retval;
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

