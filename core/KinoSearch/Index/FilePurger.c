#define C_KINO_FILEPURGER
#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/FilePurger.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/IndexManager.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/DirHandle.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/Lock.h"

/* Place unused files into purgables array and obsolete snapshot files into
 * snapfiles array. */
static void
S_discover_unused(FilePurger *self, VArray **purgables, VArray **snapfiles);

/* Clean up after a failed background merge session, adding all dead files to
 * the list of candidates to be zapped. */
static void
S_zap_dead_merge(FilePurger *self, Hash *candidates);

FilePurger*
FilePurger_new(Folder *folder, Snapshot *snapshot, IndexManager *manager)
{
    FilePurger *self = (FilePurger*)VTable_Make_Obj(FILEPURGER);
    return FilePurger_init(self, folder, snapshot, manager);
}

FilePurger*
FilePurger_init(FilePurger *self, Folder *folder, Snapshot *snapshot, 
                IndexManager *manager) 
{
    self->folder       = (Folder*)INCREF(folder);
    self->snapshot     = (Snapshot*)INCREF(snapshot);
    self->manager      = manager 
                       ? (IndexManager*)INCREF(manager)
                       : IxManager_new(NULL, NULL);
    IxManager_Set_Folder(self->manager, folder);
    return self;
}

void
FilePurger_destroy(FilePurger *self) 
{
    DECREF(self->folder);
    DECREF(self->snapshot);
    DECREF(self->manager);
    SUPER_DESTROY(self, FILEPURGER);
}

void
FilePurger_purge(FilePurger *self)
{
    Lock *deletion_lock = IxManager_Make_Deletion_Lock(self->manager);

    /* Obtain deletion lock, purge files, release deletion lock. */
    Lock_Clear_Stale(deletion_lock);
    if (Lock_Obtain(deletion_lock)) {
        Folder  *folder    = self->folder;
        bool_t   failures  = false;
        VArray  *purgables;
        VArray  *snapfiles;
        u32_t    i, max;

        S_discover_unused(self, &purgables, &snapfiles);

        /*  Attempt to delete files -- if failure, no big deal, just try again
         *  later.  Proceed in reverse lexical order so that segment
         *  directories get deleted after they've been emptied. */
        VA_Sort(purgables, NULL, NULL);
        for (i = VA_Get_Size(purgables); i--; ) {
            CharBuf *filename = (CharBuf*)VA_fetch(purgables, i);
            if (!Folder_Delete(folder, filename)) { 
                if (Folder_Exists(folder, filename)) {
                    failures = true; 
                }
            }
        }
        DECREF(purgables);

        /* Only delete the snapshot files if all of the data files were
         * successfully deleted.  If there were any failures, leave the
         * snapshots around so that the next purge might catch them. */
        if (!failures) {
            for (i = 0, max = VA_Get_Size(snapfiles); i < max; i++) {
                CharBuf *filename = (CharBuf*)VA_Fetch(snapfiles, i);
                Folder_Delete(folder, filename);
            }
        }
        DECREF(snapfiles);

        Lock_Release(deletion_lock);
    }
    else {
        WARN("Can't obtain deletion lock, skipping deletion of "
            "obsolete files");
    }

    DECREF(deletion_lock);
}

static void
S_zap_dead_merge(FilePurger *self, Hash *candidates)
{
    IndexManager *manager = self->manager;
    Lock *merge_lock   = IxManager_Make_Merge_Lock(manager);

    Lock_Clear_Stale(merge_lock);
    if (!Lock_Is_Locked(merge_lock)) { 
        Hash *merge_data = IxManager_Read_Merge_Data(manager);
        Obj  *cutoff = merge_data 
                     ? Hash_Fetch_Str(merge_data, "cutoff", 6) 
                     : NULL;

        if (cutoff) {
            CharBuf *cutoff_seg = Seg_num_to_name(Obj_To_I64(cutoff));
            if (Folder_Exists(self->folder, cutoff_seg)) {
                static ZombieCharBuf merge_json = ZCB_LITERAL("merge.json");
                DirHandle *dh = Folder_Open_Dir(self->folder, cutoff_seg);
                CharBuf *entry = dh ? DH_Get_Entry(dh) : NULL;
                CharBuf *filepath = CB_new(32);

                if (!dh) {
                    THROW(ERR, "Can't open segment dir '%o'", filepath);
                }

                Hash_Store(candidates, (Obj*)cutoff_seg, INCREF(&EMPTY));
                Hash_Store(candidates, (Obj*)&merge_json, INCREF(&EMPTY));
                while (DH_Next(dh)) {
                    /* TODO: recursively delete subdirs within seg dir. */
                    CB_setf(filepath, "%o/%o", cutoff_seg, entry);
                    Hash_Store(candidates, (Obj*)filepath, INCREF(&EMPTY));
                }
                DECREF(filepath);
                DECREF(dh);
            }
            DECREF(cutoff_seg);
        }

        DECREF(merge_data);
    }

    DECREF(merge_lock);
    return;
}

static void
S_discover_unused(FilePurger *self, VArray **purgables_ptr, 
                  VArray **snapfiles_ptr)
{
    Folder      *folder       = self->folder;
    VArray      *current      = VA_new(1);
    Hash        *candidates   = Hash_new(64);
    VArray      *snapfiles    = VA_new(1);
    CharBuf     *snapfile     = NULL;
    DirHandle   *dh           = Folder_Open_Dir(folder, NULL);
    CharBuf     *entry        = dh ? DH_Get_Entry(dh) : NULL;
    u32_t        i, max;

    if (!dh) {
        DECREF(current);
        DECREF(snapfiles);
        RETHROW(INCREF(Err_get_error()));
    }

    /* Start off with the list of files in the current snapshot. */
    if (self->snapshot) {
        VArray *some_files = Snapshot_List(self->snapshot);
        VA_Push_VArray(current, some_files);
        DECREF(some_files);
        snapfile = Snapshot_Get_Filename(self->snapshot);
        if (snapfile) { VA_Push(current, INCREF(snapfile)); }
    }

    while (DH_Next(dh)) {
        if      (!CB_Starts_With_Str(entry, "snapshot_", 9))   { continue; }
        else if (!CB_Ends_With_Str(entry, ".json", 5))         { continue; }
        else if (snapfile && CB_Equals(entry, (Obj*)snapfile)) { continue; }
        else {
            Snapshot *snapshot 
                = Snapshot_Read_File(Snapshot_new(), folder, entry);
            Lock *lock
                = IxManager_Make_Snapshot_Read_Lock(self->manager, entry);

            /* DON'T obtain the lock -- only see whether another
             * entity holds a lock on the snapshot file. */
            if (lock && Lock_Is_Locked(lock)) {
                /* The snapshot file is locked, which means someone's using
                 * that version of the index -- protect all of its files. */
                VArray *some_files = Snapshot_List(snapshot);
                u32_t new_size = VA_Get_Size(current) 
                               + VA_Get_Size(some_files)  + 1;
                VA_Grow(current, new_size);
                VA_Push(current, (Obj*)CB_Clone(entry));
                VA_Push_VArray(current, some_files);
                DECREF(some_files);
            }
            else {
                /* No one's using this snapshot, so all of its files are
                 * candidates for deletion */
                VArray *some_files = Snapshot_List(snapshot);
                u32_t i, max;
                for (i = 0, max = VA_Get_Size(some_files); i < max; i++) {
                    CharBuf *file = (CharBuf*)VA_Fetch(some_files, i);
                    Hash_Store(candidates, (Obj*)file, INCREF(&EMPTY));
                }
                VA_Push(snapfiles, (Obj*)CB_Clone(entry));
                DECREF(some_files);
            }

            DECREF(snapshot);
            DECREF(lock);
        }
    }
    DECREF(dh);

    /* Clean up after a dead segment consolidation. */
    S_zap_dead_merge(self, candidates);

    /* Eliminate any current files from the list of files to be purged. */
    for (i = 0, max = VA_Get_Size(current); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(current, i);
        DECREF(Hash_Delete(candidates, (Obj*)filename));
    }

    /* Pass back purgables and snapfiles. */
    *purgables_ptr = Hash_Keys(candidates);
    *snapfiles_ptr = snapfiles;

    DECREF(candidates);
    DECREF(current);
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

