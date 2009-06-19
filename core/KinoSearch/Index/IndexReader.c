#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/IndexReader.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/SharedLock.h"
#include "KinoSearch/Util/I32Array.h"

IndexReader*
IxReader_open(Obj *index, Snapshot *snapshot, 
              LockFactory *lock_factory)
{
    return IxReader_do_open(NULL, index, snapshot, lock_factory);
}

IndexReader*
IxReader_do_open(IndexReader *temp_self, Obj *index, Snapshot *snapshot, 
                 LockFactory *lock_factory)
{
    PolyReader *polyreader = PolyReader_open(index, snapshot, 
        lock_factory);
    if (!VA_Get_Size(PolyReader_Get_Seg_Readers(polyreader))) {
        THROW("Index doesn't seem to contain any data");
    }
    DECREF(temp_self);
    return (IndexReader*)polyreader;
}

IndexReader*
IxReader_init(IndexReader *self, Schema *schema, Folder *folder, 
              Snapshot *snapshot, VArray *segments, i32_t seg_tick, 
              LockFactory *lock_factory)
{
    snapshot = snapshot ? (Snapshot*)INCREF(snapshot) : Snapshot_new();
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    DECREF(snapshot);
    self->components     = Hash_new(0);
    self->lock_factory   = lock_factory == NULL 
                         ? NULL 
                         : (LockFactory*)INCREF(lock_factory);
    self->read_lock      = NULL;
    self->commit_lock    = NULL;
    return self;
}

void
IxReader_close(IndexReader *self)
{
    if (self->components) {
        CharBuf *key;
        DataReader *component;
        Hash_Iter_Init(self->components);
        while (Hash_Iter_Next(self->components, &key, (Obj**)&component)) {
            if (OBJ_IS_A(component, DATAREADER)) { 
                DataReader_Close(component); 
            }
        }
        Hash_Clear(self->components);
    }
    if (self->read_lock) {
        Lock_Release(self->read_lock);
        DECREF(self->read_lock);
        self->read_lock = NULL;
    }
}

void
IxReader_destroy(IndexReader *self)
{
    DECREF(self->components);
    if (self->read_lock) {
        Lock_Release(self->read_lock);
        DECREF(self->read_lock);
    }
    DECREF(self->lock_factory);
    DECREF(self->commit_lock);
    SUPER_DESTROY(self, INDEXREADER);
}

LockFactory*
IxReader_get_lock_factory(IndexReader *self) 
    { return self->lock_factory; }
Hash*
IxReader_get_components(IndexReader *self) 
    { return self->components; }

DataReader*
IxReader_obtain(IndexReader *self, const CharBuf *key)
{
    DataReader *component = (DataReader*)Hash_Fetch(self->components, key);
    if (!component) {
        THROW("No component registered for '%o'", key);
    }
    return component;
}

DataReader*
IxReader_fetch(IndexReader *self, const CharBuf *api)
{
    return (DataReader*)Hash_Fetch(self->components, api);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

