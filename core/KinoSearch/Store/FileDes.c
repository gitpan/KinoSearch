#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/FileDes.h"

i32_t FileDes_object_count = 0;

FileDes*
FileDes_init(FileDes *self, const CharBuf *path)
{
    self->path = path ? CB_Clone(path) : CB_new(0);
    self->mess = NULL;

    /* Track number of live FileDes released into the wild. */
    FileDes_object_count++;

    ABSTRACT_CLASS_CHECK(self, FILEDES);
    return self;
}

void
FileDes_destroy(FileDes *self)
{
    bool_t success = FileDes_Close(self);
    CharBuf *mess  = NULL;
    if (!success) {
        mess = CB_Clone(self->mess);
    }

    /* Decrement count of FileDes objects in existence. */
    FileDes_object_count--;

    DECREF(self->path);
    DECREF(self->mess);
    SUPER_DESTROY(self, FILEDES);

    if (!success) Err_throw_mess(ERR, mess);
}

void
FileDes_set_path(FileDes *self, const CharBuf *path)
{
    CB_Mimic(self->path, (Obj*)path);
}

CharBuf*
FileDes_get_path(FileDes *self) { return self->path; }
CharBuf*
FileDes_get_mess(FileDes *self) { return self->mess; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

