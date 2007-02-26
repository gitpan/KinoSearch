#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMLISTREADER_VTABLE
#include "KinoSearch/Index/TermListReader.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/SegTermList.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/SegTermListCache.r"
#include "KinoSearch/Store/Folder.r"

TermListReader*
TLReader_new(Schema *schema, Folder *folder, SegInfo *seg_info)
{
    u32_t i;
    SegTermList **term_lists;
    Hash *metadata 
        = (Hash*)SegInfo_Extract_Metadata(seg_info, "term_list", 9);
    CREATE(self, TermListReader, TERMLISTREADER);

    /* assign */
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    self->schema      = schema;
    self->folder      = folder;
    self->seg_info    = seg_info;

    /* derive */
    self->num_fields   = Schema_Num_Fields(schema);

    /* extract some vars from the seg_info's metadata */
    self->index_interval = Hash_Fetch_I64(metadata, "index_interval", 14);
    self->skip_interval  = Hash_Fetch_I64(metadata, "skip_interval", 13);

    /* build an array of SegTermList objects */
    term_lists = CALLOCATE(self->num_fields, SegTermList*);
    self->term_lists = term_lists;
    for (i = 0; i < self->num_fields; i++) {
        ByteBuf *field = SegInfo_Field_Name(seg_info, i);
        SegTermListCache *tl_cache 
            = SegTLCache_new(schema, folder, seg_info, field);
        if (tl_cache == NULL)
            continue;
        term_lists[i] = SegTermList_new(schema, folder, seg_info, field, 
            tl_cache, false);
        REFCOUNT_DEC(tl_cache);
    }

    return self;
}

void
TLReader_close(TermListReader *self)
{
    u32_t i;
    SegTermList **term_lists = self->term_lists;

    /* release each term list and NULL out array */
    for (i = 0; i < self->num_fields; i++) {
        REFCOUNT_DEC(term_lists[i]);
    }
    memset(term_lists, 0, self->num_fields * sizeof(void*));
}

void
TLReader_destroy(TermListReader *self)
{
    TLReader_Close(self);
    free(self->term_lists);
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    free(self);
}

static SegTermList*
obtain_term_list(TermListReader *self, kino_ByteBuf *field)
{
    i32_t field_num = SegInfo_Field_Num(self->seg_info, field);
    SegTermList *orig;

    if (field_num > (i32_t)self->num_fields) /* sanity check */
        CONFESS("Field num too big: %d %u", field_num, self->num_fields);

    /* if field isn't known, bail out */
    if (field_num == -1)
        return NULL;
    
    /* bail out if the field isn't indexed or isn't in seg */
    orig = self->term_lists[field_num];
    if (orig == NULL)
        return NULL;

    return (SegTermList*)SegTermList_Clone(orig);
}



kino_SegTermList*
TLReader_field_terms(TermListReader *self, kino_Term *target) 
{
    SegTermList *term_list;

    /* one null deserves another */
    if (target == NULL)
        return NULL;

    /* get a term list and seek it */
    term_list = obtain_term_list(self, target->field);
    if (term_list != NULL)
        SegTermList_Seek(term_list, target);

    return term_list;
}

SegTermList*
TLReader_start_field_terms(TermListReader *self, kino_ByteBuf *field)
{
    SegTermList *term_list = obtain_term_list(self, field);
    if (term_list != NULL)
        SegTermList_Reset(term_list);
    return term_list;
}

TermInfo*
TLReader_fetch_term_info(TermListReader *self, kino_Term *target) 
{
    if (target != NULL) {
        i32_t field_num = SegInfo_Field_Num(self->seg_info, target->field);
        if (field_num > (i32_t)self->num_fields) /* sanity check */
            CONFESS("Field num too big: %d %u", field_num, self->num_fields);

        if (field_num != -1) {
            SegTermList *term_list = self->term_lists[field_num];


            if (term_list != NULL) {
                Term *found;

                /* iterate until the result is ge the term */ 
                SegTermList_Seek(term_list, target);

                /*if found matches target, return info; otherwise NULL */
                found = SegTermList_Get_Term(term_list);
                if (found != NULL && Term_Equals(target, (Obj*)found)) {
                    return SegTermList_Get_Term_Info(term_list);
                }
            }
        }
    }
    return NULL;
}

kino_u32_t
kino_TLReader_get_skip_interval(kino_TermListReader *self)
{
    return self->skip_interval;
}



/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

