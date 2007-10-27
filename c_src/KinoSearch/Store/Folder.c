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
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "Open_OutStream");
    UNREACHABLE_RETURN(OutStream*);
}

OutStream*
Folder_safe_open_outstream(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "Safe_Open_OutStream");
    UNREACHABLE_RETURN(OutStream*);
}

InStream*
Folder_open_instream(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "Open_InStream");
    UNREACHABLE_RETURN(InStream*);
}

VArray*
Folder_list(Folder *self)
{
    ABSTRACT_DEATH(self, "List");
    UNREACHABLE_RETURN(VArray*);
}

bool_t
Folder_file_exists(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "File_Exists");
    UNREACHABLE_RETURN(bool_t);
}

void
Folder_rename_file(Folder *self, const ByteBuf* from, const ByteBuf *to)
{
    UNUSED_VAR(from);
    UNUSED_VAR(to);
    ABSTRACT_DEATH(self, "Rename_File");
}

void
Folder_delete_file(Folder *self, const ByteBuf *filename)
{
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "Delete_File");
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
    UNUSED_VAR(filename);
    ABSTRACT_DEATH(self, "Slurp_File");
    UNREACHABLE_RETURN(ByteBuf*);
}

void
Folder_close_f(Folder *self)
{
    ABSTRACT_DEATH(self, "Close_F");
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

