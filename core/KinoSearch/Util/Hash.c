#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

#include "KinoSearch/Obj/VTable.h"

#include "KinoSearch/Util/Hash.h"
#include "KinoSearch/Obj/Undefined.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/CharBuf.h"
#include "KinoSearch/Util/Err.h"
#include "KinoSearch/Util/Freezer.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/VArray.h"

#define HashEntry kino_HashEntry

typedef struct HashEntry {
    SharedHashKey *key;
    Obj *value;
    i32_t hash_code;
} HashEntry;

/* Reset the iterator.  Hash_iter_init must be called to restart iteration.
 */
static INLINE void
SI_kill_iter(Hash *self);

/* Return the entry associated with the key, if any.
 */
static INLINE HashEntry*
SI_fetch_entry(Hash *self, const CharBuf *key, i32_t hash_code);

/* Double the number of buckets and redistribute all entries. 
 *
 * This should be a static inline function, but right now we need to suppress
 * memory leaks from it because the VTable_registry never gets completely
 * cleaned up.
 */
HashEntry*
kino_Hash_rebuild_hash(Hash *self);

SharedKeyMasterHash *Hash_keymaster = NULL;

Hash*
Hash_new(u32_t capacity)
{
    Hash *self = (Hash*)VTable_Make_Obj(&HASH);
    return Hash_init(self, capacity);
}

Hash*
Hash_init(Hash *self, u32_t capacity)
{
    /* Allocate enough space to hold the requested number of elements without
     * triggering a rebuild. */
    u32_t requested_capacity = capacity < I32_MAX ? capacity : I32_MAX;
    u32_t threshold;
    capacity = 16;
    while (1) {
        threshold = (capacity / 3) * 2;
        if (threshold > requested_capacity) { break; }
        capacity *= 2;
    }

    /* Init. */
    self->size         = 0;
    self->iter_tick    = -1;

    /* Derive. */
    self->capacity     = capacity;
    self->entries      = CALLOCATE(capacity, HashEntry);
    self->threshold    = threshold;

    if (self != (Hash*)Hash_keymaster) {
        if (Hash_keymaster == NULL) {
            (void)SharedKeyMasterHash_new(requested_capacity);
        }
        else {
            INCREF(Hash_keymaster); 
        }
    }

    return self;
}

void 
Hash_destroy(Hash *self) 
{
    if (self->entries) {
        Hash_clear(self);
        free(self->entries);
    }
    if (DECREF(Hash_keymaster) == 0) {
        Hash_keymaster = NULL;
    }
    FREE_OBJ(self);
}

Hash*
Hash_dump(Hash *self)
{
    Hash *dump = Hash_new(self->size);
    CharBuf *key;
    Obj *value;

    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &value)) {
        Hash_Store(dump, key, Obj_Dump(value));
    }

    return dump;
}

Obj*
Hash_load(Hash *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *class_name = (CharBuf*)Hash_Fetch_Str(source, "_class", 6);
    UNUSED_VAR(self);

    /* Assume that the presence of the "_class" key paired with a valid class
     * name indicates the output of a Dump rather than an ordinary Hash. */
    if (class_name && OBJ_IS_A(class_name, CHARBUF)) {
        VTable *vtable = VTable_fetch_vtable(class_name);

        if (!vtable) {
            CharBuf *parent_class = VTable_find_parent_class(class_name);
            if (parent_class) {
                VTable *parent = VTable_singleton(parent_class, NULL);
                vtable = VTable_singleton(class_name, parent);
                DECREF(parent_class);
            }
            else {
                /* TODO: Fix Hash_Load() so that it works with ordinary hash
                 * keys named "_class". */
                THROW("Can't find class '%o'", class_name);
            }
        }

        /* Dispatch to an alternate Load() method. */
        if (vtable) {
            Obj_load_t load = (Obj_load_t)METHOD(vtable, Obj, Load);
            if (load == Obj_load) {
                THROW("Abstract method Load() not defined for %o", 
                    vtable->name);
            }
            else if (load != (Obj_load_t)Hash_load) { /* stop inf loop */
                return load(NULL, dump);
            }
        }
    }

    /* It's an ordinary Hash. */
    {
        Hash *loaded = Hash_new(source->size);
        CharBuf *key;
        Obj *value;

        Hash_Iter_Init(source);
        while (Hash_Iter_Next(source, &key, &value)) {
            Hash_Store(loaded, key, Obj_Load(value, value));
        }

        return (Obj*)loaded;
    }
}

void
Hash_serialize(Hash *self, OutStream *outstream)
{
    CharBuf *key;
    Obj *val;
    OutStream_Write_C32(outstream, self->size);
    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) {
        CB_Serialize(key, outstream);
        FREEZE(val, outstream);
    }
}

Hash*
Hash_deserialize(Hash *self, InStream *instream)
{
    u32_t size = InStream_Read_C32(instream);
    CharBuf *key = CB_new(0);

    if (self) Hash_init(self, size);
    else self = Hash_new(size);

    /* Read key/value pairs. */
    while (size--) {
        u32_t size = InStream_Read_C32(instream);
        CB_Grow(key, size);
        InStream_Read_Bytes(instream, key->ptr, size);
        CB_Set_Size(key, size);
        *CBEND(key) = '\0';
        Hash_Store(self, key, THAW(instream));
    }

    DECREF(key);
    return self;
}

void
Hash_clear(Hash *self) 
{
    HashEntry *entry       = (HashEntry*)self->entries;
    HashEntry *const limit = entry + self->capacity;

    /* Iterate through all entries. */
    for ( ; entry < limit; entry++) {
        if (!entry->key) { continue; }
        DECREF(entry->key);
        DECREF(entry->value);
        entry->key       = NULL;
        entry->value     = NULL;
        entry->hash_code = 0;
    }

    self->size = 0;
}

void
kino_Hash_do_store(Hash *self, const CharBuf *key, Obj *value, 
                   i32_t hash_code)
{
    HashEntry   *entries = self->size >= self->threshold
                         ? kino_Hash_rebuild_hash(self)
                         : (HashEntry*)self->entries;
    HashEntry   *entry;
    u32_t        tick    = hash_code;
    const u32_t  mask    = self->capacity - 1;

    while (1) {
        tick &= mask;
        entry = entries + tick;
        if (entry->key == (SharedHashKey*)UNDEF || !entry->key) {
            if (entry->key == (SharedHashKey*)UNDEF) { 
                /* Take note of diminished tombstone clutter. */
                self->threshold++; 
            }
            entry->key       = Hash_Make_Key(self, key, hash_code);
            entry->value     = value;
            entry->hash_code = hash_code;
            self->size++;
            break;
        }
        else if (   entry->hash_code == hash_code
                 && Obj_Equals(key, (Obj*)entry->key)
        ) {
            DECREF(entry->value);
            entry->value = value;
            break;
        }
        tick++; /* linear scan */
    }
}

void
Hash_store(Hash *self, const CharBuf *key, Obj *value) 
{
    kino_Hash_do_store(self, key, value, Obj_Hash_Code(key));
}

void
Hash_store_str(Hash *self, const char *key, size_t key_len, Obj *value)
{
    ZombieCharBuf key_buf = ZCB_make_str((char*)key, key_len);
    kino_Hash_do_store(self, (CharBuf*)&key_buf, value, 
        ZCB_Hash_Code(&key_buf));
}

SharedHashKey*
Hash_make_key(Hash *self, const CharBuf *key, i32_t hash_code)
{
    SharedHashKey *shared_key 
        = (SharedHashKey*)Hash_Find_Key(Hash_keymaster, key, hash_code);
    UNUSED_VAR(self);
    if (shared_key) { return (SharedHashKey*)INCREF(shared_key); }
    else { return SharedHashKey_new(key, hash_code); }
}

Obj*
Hash_fetch_str(Hash *self, const char *key, size_t key_len) 
{
    ZombieCharBuf key_buf = ZCB_BLANK;
    ZCB_Assign_Str(&key_buf, key, key_len);
    return Hash_fetch(self, (CharBuf*)&key_buf);
}

static INLINE HashEntry*
SI_fetch_entry(Hash *self, const CharBuf *key, i32_t hash_code) 
{
    u32_t tick = hash_code;
    HashEntry *const entries = (HashEntry*)self->entries;
    HashEntry *entry;

    while (1) {
        tick &= self->capacity - 1;
        entry = entries + tick;
        if (!entry->key) { 
            /* Failed to find the key, so return NULL. */
            return NULL; 
        }
        else if (   entry->hash_code == hash_code
                 && Obj_Equals(key, (Obj*)entry->key)
        ) {
            return entry;
        }
        tick++;
    }
}

Obj*
Hash_fetch(Hash *self, const CharBuf *key) 
{
    HashEntry *entry = SI_fetch_entry(self, key, Obj_Hash_Code(key));
    return entry ? entry->value : NULL;
}

Obj*
Hash_delete(Hash *self, const CharBuf *key) 
{
    HashEntry *entry = SI_fetch_entry(self, key, Obj_Hash_Code(key));
    if (entry) {
        Obj *value = entry->value;
        DECREF(entry->key);
        entry->key       = (SharedHashKey*)UNDEF;
        entry->value     = NULL;
        entry->hash_code = 0;
        self->size--;
        self->threshold--; /* limit number of tombstones */
        return value;
    }
    else {
        return NULL;
    }
}

Obj*
Hash_delete_str(Hash *self, const char *key, size_t key_len) 
{
    ZombieCharBuf key_buf = ZCB_BLANK;
    ZCB_Assign_Str(&key_buf, key, key_len);
    return Hash_delete(self, (CharBuf*)&key_buf);
}

u32_t
Hash_iter_init(Hash *self) 
{
    SI_kill_iter(self);
    return self->size;
}

static INLINE void
SI_kill_iter(Hash *self) 
{
    self->iter_tick = -1;
}

bool_t
Hash_iter_next(Hash *self, CharBuf **key, Obj **value) 
{
    while (1) {
        if (++self->iter_tick >= (i32_t)self->capacity) {
            /* Bail since we've completed the iteration. */
            --self->iter_tick;
            *key   = NULL;
            *value = NULL;
            return false;
        }
        else {
            HashEntry *const entry 
                = (HashEntry*)self->entries + self->iter_tick;
            if (entry->key && entry->key != (SharedHashKey*)UNDEF) {
                /* Success! */
                *key   = (CharBuf*)entry->key;
                *value = entry->value;
                return true;
            }
        }
    }
}

CharBuf*
Hash_find_key(Hash *self, const CharBuf *key, i32_t hash_code)
{
    HashEntry *entry = SI_fetch_entry(self, key, hash_code);
    return entry ? (CharBuf*)entry->key : NULL;
}

VArray*
Hash_keys(Hash *self) 
{
    CharBuf *key;
    Obj *val;
    VArray *keys = VA_new(self->size);
    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) {
        VA_push(keys, INCREF(key));
    }
    return keys;
}

VArray*
Hash_values(Hash *self) 
{
    CharBuf *key;
    Obj *val;
    VArray *values = VA_new(self->size);
    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) VA_push(values, INCREF(val));
    return values;
}

bool_t
Hash_equals(Hash *self, Obj *other)
{
    Hash    *evil_twin = (Hash*)other;
    CharBuf *key;
    Obj     *val;

    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, HASH)) return false;
    if (self->size != evil_twin->size) return false;

    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) {
        Obj *other_val = Hash_Fetch(evil_twin, key);
        if (!other_val || !Obj_Equals(other_val, val)) return false;
    }

    return true;
}

void
Hash_marshall(Hash *self, u32_t num_pairs, ...)
{
    va_list args;

    va_start(args, num_pairs);
    while (num_pairs--) {
        char *key = va_arg(args, char*);
        size_t key_len = strlen(key);
        Obj *val = va_arg(args, Obj*);
        Hash_Store_Str(self, key, key_len, val);
    }
    va_end(args);
}

u32_t
Hash_get_capacity(Hash *self) { return self->capacity; }
u32_t
Hash_get_size(Hash *self)     { return self->size; }

#define INDENT_STR "  " 
#define INDENT 2

static CharBuf*
S_do_dumper(Hash *self, i32_t dump_level)
{
    CharBuf *key;
    Obj *val;
    i32_t i;
    CharBuf *pad = CB_new(dump_level * INDENT);
    CharBuf *out = CB_new(self->size * (dump_level + 10));

    for (i = 0; i < dump_level; i++) {
        CB_Cat_Trusted_Str(pad, INDENT_STR, INDENT);
    }

    CB_Cat(out, pad);
    CB_Cat_Trusted_Str(out, "{\n", 2);
    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) {
        CB_Cat(out, pad);
        CB_Cat_Trusted_Str(out, INDENT_STR "\"", 1 + INDENT);
        CB_Cat(out, key);
        CB_Cat_Trusted_Str(out, "\": ", 3);
        if (OBJ_IS_A(val, HASH)) {
            CharBuf *inner_dump = S_do_dumper((Hash*)val, dump_level + 1);
            i32_t indent = INDENT * (dump_level + 1);
            CB_Cat_Trusted_Str(out, inner_dump->ptr + indent, 
                CB_Get_Size(inner_dump) - indent);
            DECREF(inner_dump);
        }
        else {
            CharBuf *val_str = Obj_To_String(val);
            CB_Cat_Trusted_Str(out, "\"", 1);
            CB_Cat(out, val_str);
            CB_Cat_Trusted_Str(out, "\"\n", 2);
            DECREF(val_str);
        }
    }
    CB_Cat(out, pad);
    CB_Cat_Trusted_Str(out, "}\n", 2);

    DECREF(pad);

    return out;
}

CharBuf*
Hash_dumper(Hash *self)
{
    return S_do_dumper(self, 0);
}

HashEntry*
kino_Hash_rebuild_hash(Hash *self)
{
    HashEntry *old_entries   = (HashEntry*)self->entries;
    HashEntry *entry         = old_entries;
    HashEntry *limit         = old_entries + self->capacity;

    SI_kill_iter(self);
    self->capacity *= 2;
    self->threshold = (self->capacity / 3) * 2;
    self->entries   = CALLOCATE(self->capacity, HashEntry);
    self->size      = 0;

    for ( ; entry < limit; entry++) {
        if (!entry->key || entry->key == (SharedHashKey*)UNDEF) {
            continue; 
        }
        kino_Hash_do_store(self, (CharBuf*)entry->key, entry->value, 
            entry->hash_code);
        DECREF(entry->key);
    }

    kino_MemMan_wrapped_free(old_entries);

    return self->entries;
}

SharedKeyMasterHash*
SharedKeyMasterHash_new(u32_t request)
{
    SharedKeyMasterHash *self = 
        (SharedKeyMasterHash*)VTable_Make_Obj(&SHAREDKEYMASTERHASH);
    return SharedKeyMasterHash_init(self, request);
}

SharedKeyMasterHash*
SharedKeyMasterHash_init(SharedKeyMasterHash *self, u32_t request)
{
    if (Hash_keymaster != NULL) {
        THROW("Hash_keymaster already initialized.");
    }
    Hash_keymaster = self;
    Hash_init((Hash*)self, request);
    return self;
}

SharedHashKey*
SharedKeyMasterHash_make_key(SharedKeyMasterHash *self, const CharBuf *key,
                             i32_t hash_code)
{
    UNUSED_VAR(self);
    UNUSED_VAR(hash_code);
    return (SharedHashKey*)INCREF(key);
}

SharedHashKey*
SharedHashKey_new(const CharBuf *source, i32_t hash_code)
{
    SharedHashKey *self = (SharedHashKey*)VTable_Make_Obj(&SHAREDHASHKEY);
    return SharedHashKey_init(self, source, hash_code);
}

SharedHashKey*
SharedHashKey_init(SharedHashKey *self, const CharBuf *source, 
                   i32_t hash_code)
{
    size_t size = CB_Get_Size(source);
    CB_init((CharBuf*)self, size);
    CB_Copy_Str(self, (char*)CB_Get_Ptr8(source), size);
    /* TODO: verify that key doesn't already exist. */
    kino_Hash_do_store((Hash*)Hash_keymaster, (CharBuf*)self, INCREF(&EMPTY), 
        hash_code);
    return self;
}

u32_t
SharedHashKey_dec_refcount(SharedHashKey *self)
{
    u32_t modified_refcount = Obj_dec_refcount((Obj*)self);
    if (modified_refcount == 1) {
        Hash_Delete(Hash_keymaster, (CharBuf*)self);
        modified_refcount = 0;
    }
    return modified_refcount;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

