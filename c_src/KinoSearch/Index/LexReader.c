#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_LEXREADER_VTABLE
#include "KinoSearch/Index/LexReader.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/SegLexicon.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/SegLexCache.r"
#include "KinoSearch/Store/Folder.r"

LexReader*
LexReader_new(Schema *schema, Folder *folder, SegInfo *seg_info)
{
    u32_t i;
    SegLexicon **lexicons;
    CREATE(self, LexReader, LEXREADER);

    /* assign */
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    self->schema      = schema;
    self->folder      = folder;
    self->seg_info    = seg_info;

    /* derive */
    self->num_fields   = Schema_Num_Fields(schema);
    self->index_interval = schema->index_interval;
    self->skip_interval  = schema->skip_interval;

    /* build an array of SegLexicon objects */
    lexicons = CALLOCATE(self->num_fields, SegLexicon*);
    self->lexicons = lexicons;
    for (i = 0; i < self->num_fields; i++) {
        ByteBuf *field = SegInfo_Field_Name(seg_info, i);
        SegLexCache *lex_cache 
            = SegLexCache_new(schema, folder, seg_info, field);
        if (lex_cache == NULL)
            continue;
        lexicons[i] = SegLex_new(schema, folder, seg_info, field, 
            lex_cache, false);
        REFCOUNT_DEC(lex_cache);
    }

    return self;
}

void
LexReader_close(LexReader *self)
{
    u32_t i;
    SegLexicon **lexicons = self->lexicons;

    /* release each lexicon and NULL out array */
    for (i = 0; i < self->num_fields; i++) {
        REFCOUNT_DEC(lexicons[i]);
    }
    memset(lexicons, 0, self->num_fields * sizeof(void*));
}

void
LexReader_destroy(LexReader *self)
{
    LexReader_Close(self);
    free(self->lexicons);
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    free(self);
}

static SegLexicon*
obtain_lexicon(LexReader *self, ByteBuf *field)
{
    i32_t field_num = SegInfo_Field_Num(self->seg_info, field);
    SegLexicon *orig;

    if (field_num > (i32_t)self->num_fields) /* sanity check */
        CONFESS("Field num too big: %d %u", field_num, self->num_fields);

    /* if field isn't known, bail out */
    if (field_num == -1)
        return NULL;
    
    /* bail out if the field isn't indexed or isn't in seg */
    orig = self->lexicons[field_num];
    if (orig == NULL)
        return NULL;

    return (SegLexicon*)SegLex_Clone(orig);
}



SegLexicon*
LexReader_look_up_term(LexReader *self, Term *target) 
{
    SegLexicon *lexicon;

    /* one null deserves another */
    if (target == NULL)
        return NULL;

    /* get a lexicon and seek it */
    lexicon = obtain_lexicon(self, target->field);
    if (lexicon != NULL)
        SegLex_Seek(lexicon, target);

    return lexicon;
}

SegLexicon*
LexReader_look_up_field(LexReader *self, ByteBuf *field)
{
    SegLexicon *lexicon = obtain_lexicon(self, field);
    if (lexicon != NULL)
        SegLex_Reset(lexicon);
    return lexicon;
}

TermInfo*
LexReader_fetch_term_info(LexReader *self, Term *target) 
{
    if (target != NULL) {
        i32_t field_num = SegInfo_Field_Num(self->seg_info, target->field);
        if (field_num > (i32_t)self->num_fields) /* sanity check */
            CONFESS("Field num too big: %d %u", field_num, self->num_fields);

        if (field_num != -1) {
            SegLexicon *lexicon = self->lexicons[field_num];


            if (lexicon != NULL) {
                Term *found;

                /* iterate until the result is ge the term */ 
                SegLex_Seek(lexicon, target);

                /*if found matches target, return info; otherwise NULL */
                found = SegLex_Get_Term(lexicon);
                if (found != NULL && Term_Equals(target, (Obj*)found)) {
                    return SegLex_Get_Term_Info(lexicon);
                }
            }
        }
    }
    return NULL;
}

u32_t
LexReader_get_skip_interval(LexReader *self)
{
    return self->skip_interval;
}



/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

