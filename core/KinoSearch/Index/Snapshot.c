#define C_KINO_SNAPSHOT
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/StringHelper.h"
#include "KinoSearch/Util/IndexFileNames.h"
#include "KinoSearch/Util/Json.h"

i32_t Snapshot_current_file_format = 2;

Snapshot*
Snapshot_new()
{
    Snapshot *self = (Snapshot*)VTable_Make_Obj(SNAPSHOT);
    return Snapshot_init(self);
}

static void
S_zero_out(Snapshot *self)
{
    DECREF(self->entries);
    DECREF(self->filename);
    self->entries  = Hash_new(0);
    self->filename = NULL;
}

Snapshot*
Snapshot_init(Snapshot *self)
{
    S_zero_out(self);
    return self;
}

void
Snapshot_destroy(Snapshot *self)
{
    DECREF(self->entries);
    DECREF(self->filename);
    SUPER_DESTROY(self, SNAPSHOT);
}

void
Snapshot_add_entry(Snapshot *self, const CharBuf *filename)
{
    Hash_Store(self->entries, (Obj*)filename, INCREF(&EMPTY));
}

bool_t
Snapshot_delete_entry(Snapshot *self, const CharBuf *entry)
{
    Obj *val = Hash_Delete(self->entries, (Obj*)entry);
    if (val) { 
        Obj_Dec_RefCount(val);
        return true;
    }
    else {
        return false;
    }
}

VArray*
Snapshot_list(Snapshot *self) { 
    return Hash_Keys(self->entries); 
}

u32_t
Snapshot_num_entries(Snapshot *self) { return Hash_Get_Size(self->entries); }

void
Snapshot_set_filename(Snapshot *self, const CharBuf *filename)
{
    DECREF(self->filename);
    self->filename = filename ? CB_Clone(filename) : NULL;
}

CharBuf*
Snapshot_get_filename(Snapshot *self) { return self->filename; }

Snapshot*
Snapshot_read_file(Snapshot *self, Folder *folder, const CharBuf *filename)
{
    /* Eliminate all prior data. Pick a snapshot file. */
    S_zero_out(self);
    self->filename = filename 
                   ? CB_Clone(filename)
                   : IxFileNames_latest_snapshot(folder); 

    if (self->filename) {
        Hash *snap_data = (Hash*)CERTIFY(
            Json_slurp_json(folder, self->filename), HASH);
        Obj *format = CERTIFY(
            Hash_Fetch_Str(snap_data, "format", 6), OBJ);

        /* Verify that we can read the index properly. */
        if (Obj_To_I64(format) > Snapshot_current_file_format) {
            THROW(ERR, "Snapshot format too recent: %i64, %i32",
                Obj_To_I64(format), Snapshot_current_file_format);
        }

        /* Build up list of entries. */
        {
            u32_t i, max;
            VArray *list = (VArray*)CERTIFY(
                Hash_Fetch_Str(snap_data, "entries", 7), VARRAY);
            Hash_Clear(self->entries);
            for (i = 0, max = VA_Get_Size(list); i < max; i++) {
                CharBuf *entry = (CharBuf*)CERTIFY(
                    VA_Fetch(list, i), CHARBUF);
                Hash_Store(self->entries, (Obj*)entry, INCREF(&EMPTY));
            }
        }

        DECREF(snap_data);
    }

    return self;
}

void
Snapshot_write_file(Snapshot *self, Folder *folder, const CharBuf *filename)
{
    Hash   *all_data = Hash_new(0);
    VArray *list     = Snapshot_List(self);

    /* Update filename. */
    DECREF(self->filename);
    if (filename) {
        self->filename = CB_Clone(filename);
    }
    else {
        CharBuf *latest = IxFileNames_latest_snapshot(folder);
        u64_t gen = latest ? IxFileNames_extract_gen(latest) + 1 : 1;
        char base36[StrHelp_MAX_BASE36_BYTES];
        StrHelp_to_base36(gen, &base36);
        self->filename = CB_newf("snapshot_%s.json", &base36);
        DECREF(latest);
    }

    /* Don't overwrite. */
    if (Folder_Exists(folder, self->filename)) {
        THROW(ERR, "Snapshot file '%o' already exists", self->filename);
    }

    /* Sort, then store file names. */
    VA_Sort(list, NULL, NULL);
    Hash_Store_Str(all_data, "entries", 7, (Obj*)list);

    /* Create a JSON-izable data structure. */
    Hash_Store_Str(all_data, "format", 6, 
        (Obj*)CB_newf("%i32", (i32_t)Snapshot_current_file_format) );

    /* Write out JSON-ized data to the new file. */
    Json_spew_json((Obj*)all_data, folder, self->filename);

    DECREF(all_data);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

