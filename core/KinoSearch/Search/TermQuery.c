#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/TermQuery.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/Span.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Index/TermVector.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Searchable.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Search/TermScorer.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Freezer.h"
#include "KinoSearch/Util/I32Array.h"

TermQuery*
TermQuery_new(const CharBuf *field, const Obj *term)
{
    TermQuery *self = (TermQuery*)VTable_Make_Obj(&TERMQUERY);
    return TermQuery_init(self, field, term);
}

TermQuery*
TermQuery_init(TermQuery *self, const CharBuf *field, const Obj *term)
{
    Query_init((Query*)self, 1.0f);
    self->field       = CB_Clone(field);
    self->term        = Obj_Clone(term);
    return self;
}

void
TermQuery_destroy(TermQuery *self)
{
    DECREF(self->field);
    DECREF(self->term);
    SUPER_DESTROY(self, TERMQUERY);
}

void
TermQuery_serialize(TermQuery *self, OutStream *outstream)
{
    CB_Serialize(self->field, outstream);
    FREEZE(self->term, outstream);
    OutStream_Write_Float(outstream, self->boost);
}

TermQuery*
TermQuery_deserialize(TermQuery *self, InStream *instream)
{
    self = self ? self : (TermQuery*)VTable_Make_Obj(&TERMQUERY);
    self->field = CB_deserialize(NULL, instream);
    self->term  = (Obj*)THAW(instream);
    self->boost = InStream_Read_Float(instream);
    return self;
}

CharBuf*
TermQuery_get_field(TermQuery *self) { return self->field; }
Obj*
TermQuery_get_term(TermQuery *self)  { return self->term; }

bool_t
TermQuery_equals(TermQuery *self, Obj *other)
{
    TermQuery *evil_twin = (TermQuery*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, TERMQUERY)) return false;
    if (self->boost != evil_twin->boost) return false;
    if (!CB_Equals(self->field, (Obj*)evil_twin->field)) return false;
    if (!Obj_Equals(self->term, evil_twin->term)) return false;
    return true;
}

CharBuf*
TermQuery_to_string(TermQuery *self)
{
    CharBuf *term_str = Obj_To_String(self->term);
    CharBuf *retval = CB_newf("%o:%o", self->field, term_str);
    DECREF(term_str);
    return retval;
}

Compiler*
TermQuery_make_compiler(TermQuery *self, Searchable *searchable, float boost) 
{
    return (Compiler*)TermCompiler_new((Query*)self, searchable, boost);
}

/******************************************************************/

TermCompiler*
TermCompiler_new(Query *parent, Searchable *searchable, float boost)
{
    TermCompiler *self = (TermCompiler*)VTable_Make_Obj(&TERMCOMPILER);
    return TermCompiler_init(self, parent, searchable, boost);
}

TermCompiler*
TermCompiler_init(TermCompiler *self, Query *parent, Searchable *searchable, 
                  float boost)
{
    Schema     *schema  = Searchable_Get_Schema(searchable);
    TermQuery  *tparent = (TermQuery*)parent;
    Similarity *sim     = Schema_Fetch_Sim(schema, tparent->field);

    /* Try harder to get a Similarity if necessary. */
    if (!sim) { sim = Schema_Get_Similarity(schema); }

    /* Init. */
    Compiler_init((Compiler*)self, parent, searchable, sim, boost);
    self->normalized_weight = 0.0f;
    self->query_norm_factor = 0.0f;

    /* Derive. */
    self->idf = Sim_IDF(sim, searchable, tparent->field, tparent->term);
    
    /* The score of any document is approximately equal to:
     *
     *    ( tf_d * idf_t / norm_d ) * ( tf_q * idf_t / norm_q )
     *
     * Here we add in the first IDF, plus user-supplied boost.
     *
     * The second clause is factored in by the call to Normalize().
     *
     * tf_d and norm_d can only be added by the Matcher, since they are
     * per-document.
     */
    self->raw_weight = self->idf * self->boost;

    /* Make final preparations. */
    Compiler_Normalize(self);

    return self;
}

bool_t
TermCompiler_equals(TermCompiler *self, Obj *other)
{
    TermCompiler *evil_twin = (TermCompiler*)other;
    if (!Compiler_equals((Compiler*)self, other)) return false;
    if (!OBJ_IS_A(evil_twin, TERMCOMPILER)) return false;
    if (self->idf != evil_twin->idf) return false;
    if (self->raw_weight != evil_twin->raw_weight) return false;
    if (self->query_norm_factor != evil_twin->query_norm_factor) return false;
    if (self->normalized_weight != evil_twin->normalized_weight) return false;
    return true;
}

void
TermCompiler_serialize(TermCompiler *self, OutStream *outstream)
{
    Compiler_serialize((Compiler*)self, outstream);
    OutStream_Write_Float(outstream, self->idf);
    OutStream_Write_Float(outstream, self->raw_weight);
    OutStream_Write_Float(outstream, self->query_norm_factor);
    OutStream_Write_Float(outstream, self->normalized_weight);
}

TermCompiler*
TermCompiler_deserialize(TermCompiler *self, InStream *instream)
{
    self = self ? self : (TermCompiler*)VTable_Make_Obj(&TERMCOMPILER);
    Compiler_deserialize((Compiler*)self, instream);
    self->idf               = InStream_Read_Float(instream);
    self->raw_weight        = InStream_Read_Float(instream);
    self->query_norm_factor = InStream_Read_Float(instream);
    self->normalized_weight = InStream_Read_Float(instream);
    return self;
}

float
TermCompiler_sum_of_squared_weights(TermCompiler *self)
{ 
    return self->raw_weight * self->raw_weight;
}

void
TermCompiler_apply_norm_factor(TermCompiler *self, float query_norm_factor) 
{
    self->query_norm_factor = query_norm_factor;

    /* Multiply raw weight by the idf and norm_q factors in this:
     * 
     *      ( tf_q * idf_q / norm_q )
     *
     * Note: factoring in IDF a second time is correct.  See formula.
     */
    self->normalized_weight = self->raw_weight * self->idf * query_norm_factor;
}

float
TermCompiler_get_weight(TermCompiler *self)
{
    return self->normalized_weight;
}

Matcher*
TermCompiler_make_matcher(TermCompiler *self, SegReader *reader, 
                          bool_t need_score)
{
    TermQuery *tparent = (TermQuery*)self->parent;
    PostingsReader *post_reader = (PostingsReader*)SegReader_Fetch(reader,
        POSTINGSREADER.name);
    PostingList *plist = post_reader 
        ? PostReader_Posting_List(post_reader, tparent->field, tparent->term)
        : NULL;

    if (plist == NULL || PList_Get_Doc_Freq(plist) == 0) {
        DECREF(plist);
        return NULL;
    }
    else {
        Matcher *retval = PList_Make_Matcher(plist, self->sim, 
            (Compiler*)self, need_score);
        DECREF(plist);
        return retval;
    }
}

VArray*
TermCompiler_highlight_spans(TermCompiler *self, Searchable *searchable, 
                             DocVector *doc_vec, const CharBuf *field)
{
    TermQuery *const parent = (TermQuery*)self->parent;
    VArray *spans = VA_new(0);
    TermVector *term_vector;
    I32Array *starts, *ends;
    u32_t i, max;
    UNUSED_VAR(searchable);

    if (!CB_Equals(parent->field, (Obj*)field)) return spans;

    /* Add all starts and ends. */
    term_vector = DocVec_Term_Vector(doc_vec, field, (CharBuf*)parent->term);
    if (!term_vector) return spans;

    starts = term_vector->start_offsets;
    ends   = term_vector->end_offsets;
    for (i = 0, max = I32Arr_Get_Size(starts); i < max; i++) {
        i32_t start  = I32Arr_Get(starts, i);
        i32_t length = I32Arr_Get(ends, i) - start;
        VA_Push(spans, 
            (Obj*)Span_new(start, length, TermCompiler_Get_Weight(self)) );
    }

    DECREF(term_vector);
    return spans;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

