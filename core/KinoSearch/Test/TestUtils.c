#define C_KINO_TESTUTILS
#include "KinoSearch/Util/ToolSet.h"
#include <stdarg.h>
#include <string.h>

#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Search/TermQuery.h"
#include "KinoSearch/Search/PhraseQuery.h"
#include "KinoSearch/Search/LeafQuery.h"
#include "KinoSearch/Search/ANDQuery.h"
#include "KinoSearch/Search/NOTQuery.h"
#include "KinoSearch/Search/ORQuery.h"
#include "KinoSearch/Search/RangeQuery.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/RAMFile.h"
#include "KinoSearch/Util/Freezer.h"

u64_t
TestUtils_random_u64()
{
    u64_t num =    ((u64_t)rand() << 60)
                 | ((u64_t)rand() << 45)
                 | ((u64_t)rand() << 30)
                 | ((u64_t)rand() << 15) 
                 | ((u64_t)rand() << 0);
    return num;
}

i64_t*
TestUtils_random_i64s(i64_t *buf, size_t count, i64_t min, i64_t limit) 
{
    u64_t  range = min < limit ? limit - min : 0;
    i64_t *ints = buf ? buf : (i64_t*)CALLOCATE(count, sizeof(i64_t));
    size_t i;
    for (i = 0; i < count; i++) {
        ints[i] = min + TestUtils_random_u64() % range;
    }
    return ints;
}

u64_t*
TestUtils_random_u64s(u64_t *buf, size_t count, u64_t min, u64_t limit) 
{
    u64_t  range = min < limit ? limit - min : 0;
    u64_t *ints = buf ? buf : (u64_t*)CALLOCATE(count, sizeof(u64_t));
    size_t i;
    for (i = 0; i < count; i++) {
        ints[i] = min + TestUtils_random_u64() % range;
    }
    return ints;
}

double*
TestUtils_random_f64s(double *buf, size_t count) 
{
    double *f64s = buf ? buf : (double*)CALLOCATE(count, sizeof(double));
    size_t i;
    for (i = 0; i < count; i++) {
        u64_t num = TestUtils_random_u64();
        f64s[i] = (double)num / U64_MAX;
    }
    return f64s;
}

VArray*
TestUtils_doc_set()
{
    VArray *docs = VA_new(10);

    VA_Push(docs, (Obj*)TestUtils_get_cb("x"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("y"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("z"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("x a"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("x a b"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("x a b c"));
    VA_Push(docs, (Obj*)TestUtils_get_cb("x foo a b c d"));
    
    return docs;
}

CharBuf*
TestUtils_get_cb(const char *ptr)
{
    return CB_new_from_utf8(ptr, strlen(ptr));
}

PolyQuery*
TestUtils_make_poly_query(u32_t boolop, ...)
{
    va_list args;
    Query *child;
    PolyQuery *retval;
    VArray *children = VA_new(0);

    va_start(args, boolop);
    while (NULL != (child = va_arg(args, Query*))) {
        VA_Push(children, (Obj*)child);
    }
    va_end(args);

    retval = boolop == BOOLOP_OR 
                    ? (PolyQuery*)ORQuery_new(children)
                    : (PolyQuery*)ANDQuery_new(children);
    DECREF(children);
    return retval;
}

TermQuery*
TestUtils_make_term_query(const char *field, const char *term)
{
    ZombieCharBuf field_cb = ZCB_BLANK;
    ZombieCharBuf term_cb  = ZCB_BLANK;
    ZCB_Assign_Str(&field_cb, field, strlen(field));
    ZCB_Assign_Str(&term_cb, term, strlen(term));
    return TermQuery_new((CharBuf*)&field_cb, (Obj*)&term_cb);
}

PhraseQuery*
TestUtils_make_phrase_query(const char *field, ...)
{
    ZombieCharBuf field_cb = ZCB_make_str((char*)field, strlen(field));
    va_list args;
    VArray *terms = VA_new(0);
    PhraseQuery *query;
    char *term_str;

    va_start(args, field);
    while (NULL != (term_str = va_arg(args, char*))) {
        VA_Push(terms, (Obj*)TestUtils_get_cb(term_str));
    }
    va_end(args);

    query = PhraseQuery_new((CharBuf*)&field_cb, terms);
    DECREF(terms);
    return query;
}

LeafQuery*
TestUtils_make_leaf_query(const char *field, const char *term)
{
    ZombieCharBuf field_cb = ZCB_BLANK;
    ZombieCharBuf term_cb  = ZCB_BLANK;
    CharBuf *field_ptr     = NULL;
    ZCB_Assign_Str(&term_cb, term, strlen(term));
    if (field) { 
        ZCB_Assign_Str(&field_cb, field, strlen(field));
        field_ptr = (CharBuf*)&field_cb;
    }
    return LeafQuery_new(field_ptr, (CharBuf*)&term_cb);
}

NOTQuery*
TestUtils_make_not_query(Query* negated_query)
{
    NOTQuery *not_query = NOTQuery_new(negated_query);
    DECREF(negated_query);
    return not_query;
}

RangeQuery*
TestUtils_make_range_query(const char *field, const char *lower_term,
                           const char *upper_term, bool_t include_lower,
                           bool_t include_upper)
{
    ZombieCharBuf f = ZCB_make_str((char*)field, strlen(field));
    ZombieCharBuf lterm = ZCB_make_str((char*)lower_term, strlen(lower_term));
    ZombieCharBuf uterm = ZCB_make_str((char*)upper_term, strlen(upper_term));
    return RangeQuery_new((CharBuf*)&f, (Obj*)&lterm, (Obj*)&uterm,
        include_lower, include_upper);
}

Obj*
TestUtils_freeze_thaw(Obj *object)
{
    if (object) {
        RAMFile *ram_file = RAMFile_new(NULL, false);
        OutStream *outstream = OutStream_open((Obj*)ram_file);
        FREEZE(object, outstream);
        OutStream_Close(outstream);
        DECREF(outstream);
        {
            InStream *instream = InStream_open((Obj*)ram_file);
            Obj *retval = THAW(instream);
            DECREF(instream);
            DECREF(ram_file);
            return retval;
        }
    }
    else {
        return NULL;
    }
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

