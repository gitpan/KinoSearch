#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGLEXCACHE_VTABLE
#include "KinoSearch/Index/SegLexCache.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/FieldSpec.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/SegLexicon.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Store/Folder.r"

/* Iterate through a SegLexicon reading the .lexx file, caching term texts 
 * and tinfos.
 */
static void
fill_cache(SegLexCache* self);

SegLexCache*
SegLexCache_new(Schema *schema, Folder *folder, SegInfo *seg_info, 
            const struct kino_ByteBuf *field)
{
    SegLexCache *self;
    FieldSpec *fspec = Schema_Fetch_FSpec(schema, field);
    ByteBuf *filename;
    const ByteBuf empty = BYTEBUF_BLANK;
    i32_t field_num     = SegInfo_Field_Num(seg_info, field);

    /* if the field isn't indexed, bail out */
    if ( !fspec || !fspec->indexed )
        return NULL;


    /* bail out if there are no terms for this field in this segment */
    field_num = SegInfo_Field_Num(seg_info, field);
    filename = BB_new(40);
    BB_Cat_BB(filename, seg_info->seg_name);
    BB_Cat_Str(filename, ".lexx", 5);
    BB_Cat_I64(filename, (i64_t)field_num);
    if ( !Folder_File_Exists(folder, filename) ) {
        REFCOUNT_DEC(filename);
        return NULL;
    }
    REFCOUNT_DEC(filename);

    /* CREATE */
    self            = MALLOCATE(1, SegLexCache);
    self->_         = &SEGLEXCACHE;
    self->refcount  = 1;

    /* init */
    self->term_texts        = NULL;
    self->tinfos            = NULL;
    self->locked            = false;
    self->tick              = 0;

    /* derive */
    self->term              = Term_new(field, &empty);
    self->field_num         = field_num;
    self->index_interval    = schema->index_interval;

    /* assign */
    self->schema            = REFCOUNT_INC(schema);
    self->folder            = REFCOUNT_INC(folder);
    self->seg_info          = REFCOUNT_INC(seg_info);
    self->field             = BB_CLONE(field);

    /* allocate and fill caches */
    fill_cache(self);

    return self;
}

static void
fill_cache(SegLexCache* self) 
{
    TermInfo   **tinfos;
    ByteBuf    **term_texts;
    SegLexicon *seed_lexicon = SegLex_new(self->schema, self->folder,
        self->seg_info, self->field, NULL, true);

    /* allocate space */
    self->size       = seed_lexicon->size;
    self->term_texts = MALLOCATE((u32_t)self->size, ByteBuf*); 
    self->tinfos     = MALLOCATE((u32_t)self->size, TermInfo*);
    tinfos           = self->tinfos;
    term_texts       = self->term_texts;

    /* copy tinfo and term_texts into caches */
    while (SegLex_Next(seed_lexicon)) {
        Term     *const term  = SegLex_Get_Term(seed_lexicon);
        TermInfo *const tinfo = SegLex_Get_Term_Info(seed_lexicon);
        *tinfos++     = (TermInfo*)Obj_Clone(tinfo);
        *term_texts++ = BB_CLONE(term->text);
    } 

    /* clean up */
    REFCOUNT_DEC(seed_lexicon);
}

void
SegLexCache_destroy(SegLexCache *self) 
{    
    /* free caches */
    i32_t       i;
    ByteBuf   **term_texts = self->term_texts;
    TermInfo  **tinfos     = self->tinfos;
    for (i = 0; i < self->size; i++) {
        REFCOUNT_DEC(*term_texts);
        REFCOUNT_DEC(*tinfos);
        term_texts++, tinfos++;
    }
    free(self->term_texts);
    free(self->tinfos);

    /* kill off members */
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->term);
    REFCOUNT_DEC(self->field);

    /* last, the object itself */
    free(self);
}

void
SegLexCache_lock(SegLexCache *self)
{
    if (self->locked)
        CONFESS("Lexicon is already locked");
    self->locked = true;
}

void
SegLexCache_unlock(SegLexCache *self)
{
    if ( !self->locked )
        CONFESS("Lexicon isn't locked");
    self->locked = false;
}

kino_TermInfo*
SegLexCache_get_term_info(SegLexCache *self)
{
    return self->tinfos[ self->tick ];
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

