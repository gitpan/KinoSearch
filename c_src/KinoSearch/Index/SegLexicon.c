#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGLEXICON_VTABLE
#include "KinoSearch/Index/SegLexicon.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/TermStepper.r"
#include "KinoSearch/Index/SegLexCache.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Util/IntMap.r"

/* Iterate until the state is greater than or equal to [term].
 */
static void
scan_to(SegLexicon *self, Term *term);

SegLexicon*
SegLex_new(Schema *schema, Folder *folder, SegInfo *seg_info, 
           const ByteBuf *field, SegLexCache *lex_cache, bool_t is_index) 
{
    char *metadata_key = is_index ? "lexicon_index" : "lexicon";
    Hash *metadata = (Hash*)SegInfo_Extract_Metadata(seg_info, metadata_key,
        strlen(metadata_key));
    Hash *counts = (Hash*)Hash_Fetch(metadata, "counts", 6);
    ByteBuf *filename = BB_new(30);
    CREATE(self, SegLexicon, SEGLEXICON);

    /* derive */
    self->field_num      = SegInfo_Field_Num(seg_info, field);
    self->index_interval = schema->index_interval;
    self->skip_interval  = schema->skip_interval;

    /* assign */
    self->is_index       = is_index;
    self->field          = BB_CLONE(field);
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    self->schema         = schema;
    self->folder         = folder;
    self->seg_info       = seg_info;

    /* cache can be null, if this enum is being used to fill a cache */
    if (lex_cache != NULL)
        REFCOUNT_INC(lex_cache);
    self->lex_cache = lex_cache;

    /* open instream */
    BB_Cat_BB(filename, seg_info->seg_name);
    if (is_index)
        BB_Cat_Str(filename, ".lexx", 5);
    else
        BB_Cat_Str(filename, ".lex", 4);
    BB_Cat_I64(filename, (i64_t)self->field_num);
    self->instream = Folder_Open_InStream(folder, filename);
    REFCOUNT_DEC(filename);

    /* check format */
    if (Hash_Fetch_I64(metadata, "format", 6) > LEXICON_FORMAT ) {
        CONFESS("Unsupported lexicon format: %d",
            Hash_Fetch_I64(metadata, "format", 6));
    }

    /* extract some vars from the seg_info's metadata */
    if (counts == NULL)
        CONFESS("Failed to extract 'counts' from '%s'", metadata_key);
    self->size = Hash_Fetch_I64(counts, field->ptr, field->len);

    /* define the term_num of the Enum as "not yet started" */
    self->term_num = -1;

    /* get a TermStepper */
    self->term_stepper = TermStepper_new(field, self->skip_interval, 
        is_index);

    return self;
}

void
SegLex_destroy(SegLexicon *self) 
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->term_stepper);
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->lex_cache);
    REFCOUNT_DEC(self->instream);
    free(self);
}

void
SegLex_seek(SegLexicon *self, Term *term)
{
    SegLexCache *const lex_cache = self->lex_cache;
    if (lex_cache == NULL)
        CONFESS("Can't seek - SegLexCache is NULL");

    /* reset upon null term */
    if (term == NULL) {
        SegLex_Reset(self);
        return;
    }
    /* verify field */
    else if ( BB_compare(&(self->field), &(term->field)) != 0 ) {
        CONFESS("Wrong field: '%s', '%s'", term->field, self->field);
    }

    /* begin transaction */
    SegLexCache_Lock(lex_cache);

    /* use the cache to get into the ballpark */
    SegLexCache_Seek(lex_cache, term);
    TermStepper_Set_TInfo( self->term_stepper, 
        SegLexCache_Get_Term_Info(lex_cache) );
    TermStepper_Set_Term( self->term_stepper, 
        SegLexCache_Get_Term(lex_cache) );
    InStream_SSeek(self->instream, self->term_stepper->tinfo->index_filepos);
    self->term_num = SegLexCache_Get_Term_Num(lex_cache);

    /* end transaction */
    SegLexCache_Unlock(lex_cache);

    /* scan to get to the precise location */
    scan_to(self, term);
}

SegLexicon*
SegLex_clone(SegLexicon *self)
{
    SegLexicon *evil_twin = SegLex_new(self->schema, self->folder,
        self->seg_info, self->field, self->lex_cache, self->is_index);

    /* sync the clone's state */
    InStream_SSeek(evil_twin->instream, InStream_STell(self->instream));
    evil_twin->term_num = self->term_num;
    TermStepper_Copy(evil_twin->term_stepper, self->term_stepper);

    return evil_twin;
}

void
SegLex_reset(SegLexicon* self) 
{
    self->term_num = -1;
    InStream_SSeek(self->instream, 0);
    TermStepper_Reset(self->term_stepper);
}

i32_t
SegLex_get_field_num(SegLexicon *self)
{
    return self->field_num;
}

i32_t
SegLex_get_term_num(SegLexicon *self)
{
    return self->term_num;
}

Term*
SegLex_get_term(SegLexicon *self)
{
    return self->term_stepper->term;
}

TermInfo*
SegLex_get_term_info(SegLexicon *self)
{
    return self->term_stepper->tinfo;
}

bool_t 
SegLex_next(SegLexicon *self) 
{
    /* if we've run out of terms, null out and return */
    if (++self->term_num >= self->size) {
        self->term_num = self->size; /* don't keep growing */
        TermStepper_Reset(self->term_stepper);
        return false;
    }

    /* read next term/terminfo */
    TermStepper_Read_Record(self->term_stepper, self->instream);

    return true;
}

static void
scan_to(SegLexicon *self, Term *term)
{
    /* (mildly evil encapsulation violation, since term can be null) */
    ByteBuf    *const current_text  = self->term_stepper->term->text;
    ByteBuf    *const target        = term->text;

    /* keep looping until the term text is lexically ge target */
    do {
        const i32_t comparison = BB_compare(&current_text, &target);
        if ( comparison >= 0 &&  self->term_num != -1) {
            break;
        }
    } while (SegLex_Next(self));
}

IntMap*
SegLex_build_sort_cache(SegLexicon *self, PostingList *plist, u32_t max_doc)
{
    i32_t *ints = MALLOCATE(max_doc, i32_t);
    i32_t term_num = 0;
    i32_t i;
    
    for (i = 0; i < max_doc; i++) {
        ints[i] = -1;
    }
    
    SegLex_Reset(self);

    while (SegLex_Next(self)) {
        PList_Seek_Lex(plist, (Lexicon*)self);
            
        /* assign the same sort position to all docs with this term */
        while (PList_Next(plist)) {
            ints[ PList_Get_Doc_Num(plist) ] = term_num;
        }
        term_num++;
    }

    return IntMap_new(ints, max_doc);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

