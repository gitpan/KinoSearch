#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/FilePurger.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/SharedLock.h"

/* Place unused files into purgables array and obsolete snapshot files into
 * snapfiles array. */
static void
S_discover_unused(FilePurger *self, VArray **purgables, VArray **snapfiles);

FilePurger*
FilePurger_new(Folder *folder, Snapshot *snapshot, LockFactory *lock_factory)
{
    FilePurger *self = (FilePurger*)VTable_Make_Obj(&FILEPURGER);
    return FilePurger_init(self, folder, snapshot, lock_factory);
}

FilePurger*
FilePurger_init(FilePurger *self, Folder *folder, Snapshot *snapshot, 
                LockFactory *lock_factory) 
{
    self->folder       = (Folder*)INCREF(folder);
    self->snapshot     = snapshot ? (Snapshot*)INCREF(snapshot) : NULL;
    self->lock_factory = lock_factory 
                       ? (LockFactory*)INCREF(lock_factory)
                       : LockFact_new(folder, (CharBuf*)&EMPTY);
    return self;
}

void
FilePurger_destroy(FilePurger *self) 
{
    DECREF(self->folder);
    DECREF(self->snapshot);
    DECREF(self->lock_factory);
    FREE_OBJ(self);
}

void
FilePurger_purge(FilePurger *self)
{
    Lock *commit_lock = LockFact_Make_Lock(self->lock_factory, 
        (CharBuf*)Lock_commit_lock_name, Lock_commit_lock_timeout);

    /* Obtain commit lock, purge files, release commit lock. */
    Lock_Clear_Stale(commit_lock);
    if (Lock_Obtain(commit_lock)) {
        Folder  *folder    = self->folder;
        bool_t   failures  = false;
        VArray  *purgables;
        VArray  *snapfiles;
        u32_t    i, max;

        /*  Attempt to delete files -- if failure, no big deal, just try again
         *  later.  Proceed in reverse lexical order so that segment
         *  directories get deleted after they've been emptied. */
        S_discover_unused(self, &purgables, &snapfiles);
        VA_Sort(purgables, NULL);
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

        Lock_Release(commit_lock);
    }
    else {
        WARN("Can't obtain commit lock, skipping deletion of obsolete files");
    }

    DECREF(commit_lock);
}

static void
S_discover_unused(FilePurger *self, VArray **purgables_ptr, 
                  VArray **snapfiles_ptr)
{
    LockFactory *lock_factory = self->lock_factory;
    Folder      *folder       = self->folder;
    VArray      *files        = Folder_List(folder);
    VArray      *current      = VA_new(1);
    Hash        *candidates   = Hash_new(VA_Get_Size(files));
    VArray      *snapfiles    = VA_new(1);
    CharBuf     *snapfile     = NULL;
    u32_t        i, max;

    /* Start off with the list of files in the current snapshot. */
    if (self->snapshot) {
        VArray *some_files = Snapshot_List(self->snapshot);
        VA_Push_VArray(current, some_files);
        DECREF(some_files);
        snapfile = Snapshot_Get_Filename(self->snapshot);
        if (snapfile) { VA_Push(current, INCREF(snapfile)); }
    }

    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);
        if      (!CB_Starts_With_Str(filename, "snapshot_", 9))   { continue; }
        else if (!CB_Ends_With_Str(filename, ".json", 5))         { continue; }
        else if (snapfile && CB_Equals(filename, (Obj*)snapfile)) { continue; }
        else {
            Snapshot *snapshot 
                = Snapshot_Read_File(Snapshot_new(), folder, filename);
            SharedLock *lock;
            ZombieCharBuf lock_name = ZCB_BLANK;
            size_t len = sizeof("snapshot_") - 1;

            /* Extract lock name from filename. */
            while ( isalnum(CB_Code_Point_At(filename, len)) ) { len++; }
            ZCB_Assign(&lock_name, filename);
            ZCB_Set_Size(&lock_name, len);

            /* Create a lock but DON'T obtain it --  only see whether another
             * entity holds a lock on the snapshot file. */
            lock = LockFact_Make_Shared_Lock(lock_factory, 
                (CharBuf*)&lock_name, 0);
            if (Lock_Is_Locked(lock)) {
                /* The snapshot file is locked, which means someone's using
                 * that version of the index -- protect all of its files. */
                VArray *some_files = Snapshot_List(snapshot);
                u32_t new_size = VA_Get_Size(current) 
                               + VA_Get_Size(some_files)  + 1;
                VA_Grow(current, new_size);
                VA_Push(current, INCREF(filename));
                VA_Push_VArray(current, some_files);
                DECREF(some_files);
            }
            else {
                /* No one's using this snapshot, so all of its files are
                 * candidates for deletion */
                VArray *some_files = Snapshot_List(snapshot);
                u32_t i, max;
                for (i = 0, max = VA_Get_Size(some_files); i < max; i++) {
                    CharBuf *filename = (CharBuf*)VA_Fetch(some_files, i);
                    Hash_Store(candidates, filename, INCREF(&EMPTY));
                }
                VA_Push(snapfiles, INCREF(filename));
                DECREF(some_files);
            }

            DECREF(snapshot);
            DECREF(lock);
        }
    }

    /* Eliminate any current files from the list of files to be purged. */
    for (i = 0, max = VA_Get_Size(current); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(current, i);
        DECREF(Hash_Delete(candidates, filename));
    }

    /* Pass back purgables and snapfiles. */
    *purgables_ptr = Hash_Keys(candidates);
    *snapfiles_ptr = snapfiles;

    DECREF(candidates);
    DECREF(files);
    DECREF(current);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

