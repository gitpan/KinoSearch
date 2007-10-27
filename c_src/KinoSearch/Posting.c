#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_POSTING_VTABLE
#include "KinoSearch/Posting.r"

#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Search/Similarity.r"

void
Post_destroy(Posting *self)
{
    REFCOUNT_DEC(self->sim);
    free(self);
}

void
Post_reset(Posting *self, u32_t doc_num)
{
    UNUSED_VAR(doc_num);
    ABSTRACT_DEATH(self, "Post_Reset");
}

struct kino_RawPosting*
Post_read_raw(Posting *self, InStream *instream, u32_t last_doc_num, 
              ByteBuf *term_text, struct kino_MemoryPool *mem_pool)
{
    UNUSED_VAR(instream);
    UNUSED_VAR(last_doc_num);
    UNUSED_VAR(term_text);
    UNUSED_VAR(mem_pool);
    ABSTRACT_DEATH(self, "Post_Read_Raw");
    UNREACHABLE_RETURN(struct kino_RawPosting*);
}

void
Post_add_batch_to_pool(kino_Posting *self, 
                       struct kino_PostingPool *post_pool, 
                       struct kino_TokenBatch *batch, 
                       struct kino_FieldSpec *fspec, 
                       u32_t doc_num, float doc_boost, 
                       float length_norm)
{
    UNUSED_VAR(post_pool);
    UNUSED_VAR(batch);
    UNUSED_VAR(fspec);
    UNUSED_VAR(doc_num);
    UNUSED_VAR(doc_boost);
    UNUSED_VAR(length_norm);
    ABSTRACT_DEATH(self, "Post_Add_Batch_To_Pool");
}

struct kino_Scorer*
Post_make_scorer(kino_Posting *self, struct kino_Similarity *sim,
                 struct kino_PostingList *plist,
                 void *weight, float weight_val)
{
    UNUSED_VAR(sim);
    UNUSED_VAR(plist);
    UNUSED_VAR(weight);
    UNUSED_VAR(weight_val);
    ABSTRACT_DEATH(self, "Make_Scorer");
    UNREACHABLE_RETURN(struct kino_Scorer*);
}

Posting*
Post_dupe(Posting *self, Similarity *sim)
{
    UNUSED_VAR(sim);
    ABSTRACT_DEATH(self, "Post_Dupe");
    UNREACHABLE_RETURN(Posting*);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

