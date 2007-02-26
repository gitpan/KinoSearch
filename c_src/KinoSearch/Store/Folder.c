#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FOLDER_VTABLE
#include "KinoSearch/Store/Folder.r"

#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/Lock.r"
#include "KinoSearch/Store/OutStream.r"

OutStream*
Folder_open_outstream(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(self);
    UNUSED_VAR(filename);
    CONFESS("Folder_Open_OutStream must be defined in a subclass");
    UNREACHABLE_RETURN(OutStream*);
}

InStream*
Folder_open_instream(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(self);
    UNUSED_VAR(filename);
    CONFESS("Folder_Open_InStream must be defined in a subclass");
    UNREACHABLE_RETURN(InStream*);
}

VArray*
Folder_list(Folder *self)
{
    UNUSED_VAR(self);
    CONFESS("Folder_List must be defined in a subclass");
    UNREACHABLE_RETURN(VArray*);
}

bool_t
Folder_file_exists(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(self);
    UNUSED_VAR(filename);
    CONFESS("Folder_File_Exists must be defined in a subclass");
    UNREACHABLE_RETURN(bool_t);
}

void
Folder_rename_file(Folder *self, const ByteBuf* from, const ByteBuf *to)
{
    UNUSED_VAR(self);
    UNUSED_VAR(from);
    UNUSED_VAR(to);
    CONFESS("Folder_Rename_File must be defined in a subclass");
}

void
Folder_delete_file(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(self);
    UNUSED_VAR(filename);
    CONFESS("Folder_Delete_File must be defined in a subclass");
}

ByteBuf*
Folder_latest_gen(Folder *self, const ByteBuf *base, const ByteBuf *ext)
{
    VArray *file_list = Folder_List(self);
    ByteBuf *retval   = IxFileNames_latest_gen(file_list, base, ext);
    if (retval != NULL)
        REFCOUNT_INC(retval);
    REFCOUNT_DEC(file_list);
    return retval;
}

ByteBuf*
Folder_slurp_file(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(self);
    UNUSED_VAR(filename);
    CONFESS("Folder_Slurp_File must be defined in a subclass");
    UNREACHABLE_RETURN(ByteBuf*);
}

Lock*
Folder_make_lock(Folder *self, const ByteBuf *lock_name, 
                 const ByteBuf *lock_id, i32_t timeout)
{
    return Lock_new(self, lock_name, lock_id, timeout);
}

void
Folder_run_locked(Folder *self, const ByteBuf *lock_name, 
                  const ByteBuf *lock_id, i32_t timeout, 
                  void(*func)(void *arg), void *arg)
{
    Lock *lock = Folder_Make_Lock(self, lock_name, lock_id, timeout);
    func(arg);
    Lock_Release(lock);
    REFCOUNT_DEC(lock);
}

void
Folder_close_f(Folder *self)
{
    UNUSED_VAR(self);
    CONFESS("Folder_Close_F must be defined in a subclass");
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

