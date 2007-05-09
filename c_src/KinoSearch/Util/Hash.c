#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>

#define KINO_WANT_HASH_VTABLE
#include "KinoSearch/Util/Hash.r"

#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

#define HashEntry kino_HashEntry

struct HashEntry {
    HashEntry *next;
    ByteBuf *key;
    Obj *value;
    i32_t hash_val;
};

static HashEntry*
new_entry(const ByteBuf *key, Obj *value, i32_t hash_val, HashEntry *next);

/* Reset all iterator values.  Hash_iter_init must be called to start
 * iterator again.
 */
static void
kill_iter(Hash *self);

/* Double the number of buckets and redistribute all entries. 
 */
static void
rebuild_hash(Hash *self);

Hash*
Hash_new(u32_t proposed_capacity)
{
    u32_t capacity;
    CREATE(self, Hash, HASH);

    /* set a minumum capacity */
    if (proposed_capacity < 16)
        capacity = 16;
    else 
        capacity = proposed_capacity * 3/2;

    /* init */
    self->size = 0;
    self->next_entry = NULL;
    self->iter_bucket = 0;

    /* assign */
    self->num_buckets  = capacity;

    /* derive */
    self->buckets   = CALLOCATE(capacity, HashEntry*);
    self->threshold = capacity * 3 / 4;

    return self;
}

void
Hash_clear(Hash *self) 
{
    HashEntry **bucket = self->buckets;
    HashEntry **bucket_limit = self->buckets + self->num_buckets;

    /* go through each bucket */
    for ( ; bucket < bucket_limit; bucket++) {
        HashEntry *entry = *bucket;
        while (entry != NULL) {
            HashEntry *const next_entry = entry->next;
            REFCOUNT_DEC(entry->key);
            REFCOUNT_DEC(entry->value);
            free(entry);
            entry = next_entry;
        }
        *bucket = NULL;
    }

    self->size = 0;
}

void 
Hash_destroy(Hash *self) 
{
    Hash_clear(self);
    free(self->buckets);
    free(self);
}

static HashEntry*
new_entry(const ByteBuf *key, Obj *value, i32_t hash_val, HashEntry *next)
{
    HashEntry *entry = MALLOCATE(1, HashEntry);

    /* assign */
    entry->key         = BB_CLONE(key);
    entry->value       = value;
    entry->hash_val    = hash_val;
    entry->next        = next;

    /* manage refcounts */
    REFCOUNT_INC(value);

    return entry;
}

void
Hash_store_bb(Hash *self, const ByteBuf *key, Obj *value) 
{
    i32_t hash_val = Obj_Hash_Code(key);
    HashEntry **bucket;

    if (self->size >= self->threshold)
        rebuild_hash(self);

    bucket = self->buckets + (hash_val % self->num_buckets);

    if (*bucket == NULL) {
        HashEntry *entry = new_entry(key, value, hash_val, NULL);
        *bucket = entry;
        self->size++;
    }
    else {
        HashEntry *collider = *bucket;
        for ( ; collider != NULL; collider = collider->next) {
            if (Obj_Equals(key, (Obj*)collider->key)) {
                REFCOUNT_DEC(collider->value);
                REFCOUNT_INC(value);
                collider->value = value;
                break;
            }
            if (collider->next == NULL) {
                collider->next = new_entry(key, value, hash_val, NULL);
                self->size++;
                break;
            }
        }
    }
}

void
Hash_store(Hash *self, const char *str, size_t len, Obj *value)
{
    ByteBuf key = BYTEBUF_BLANK;
    key.ptr = (char*)str;
    key.len = len;
    Hash_store_bb(self, &key, value);
}

void 
Hash_store_i64(Hash *self, const char *str, size_t key_len, i64_t num)
{
    ByteBuf *value = BB_new_i64(num);
    ByteBuf key = BYTEBUF_BLANK;
    key.ptr = (char*)str;
    key.len = key_len;
    Hash_store_bb(self, &key, (Obj*)value);
    REFCOUNT_DEC(value);
}

Obj*
Hash_fetch(Hash *self, const char *key, size_t key_len) 
{
    ByteBuf bb = BYTEBUF_BLANK;
    bb.ptr = (char*)key;
    bb.len = key_len;
    return Hash_fetch_bb(self, &bb);
}

Obj*
Hash_fetch_bb(Hash *self, const ByteBuf *key) 
{
    i32_t hash_val = Obj_Hash_Code(key);
    HashEntry **bucket = self->buckets + (hash_val % self->num_buckets);

    if (*bucket != NULL) {
        HashEntry *entry = *bucket;
        for ( ; entry != NULL; entry = entry->next) {
            if (   entry->hash_val == hash_val
                && Obj_Equals(key, (Obj*)entry->key)
            ) {
                return entry->value;
            }
        }
    }

    /* failed to find the key, so return NULL */
    return NULL;
}

i64_t
Hash_fetch_i64(kino_Hash *self, const char *key, size_t key_len)
{
    ByteBuf *val;
    ByteBuf key_bb = BYTEBUF_BLANK;
    key_bb.ptr = (char*)key;
    key_bb.len = key_len;

    val = (ByteBuf*)Hash_fetch_bb(self, &key_bb);
    if (val == NULL || !OBJ_IS_A(val, BYTEBUF))
        CONFESS("Failed to extract number from hash for %s", key);

    return BB_To_I64(val);
}

bool_t
Hash_delete_bb(Hash *self, const ByteBuf *key) 
{
    i32_t hash_val = Obj_Hash_Code(key);
    HashEntry **bucket = self->buckets + (hash_val % self->num_buckets);

    if (*bucket != NULL) {
        HashEntry *entry = *bucket;
        if (hash_val == entry->hash_val) {
            *bucket = entry->next;
            REFCOUNT_DEC(entry->key);
            REFCOUNT_DEC(entry->value);
            free(entry);
            self->size--;
            return true;
        }
        while (entry->next != NULL) {
            HashEntry *const last_entry = entry;
            entry = entry->next;
            if (hash_val == entry->hash_val) {
                last_entry->next = entry->next;
                REFCOUNT_DEC(entry->key);
                REFCOUNT_DEC(entry->value);
                free(entry);
                self->size--;
                return true;
            }
        }
    }

    /* didn't find the key */
    return false;
}

bool_t
Hash_delete(Hash *self, const char *key, size_t key_len) 
{
    ByteBuf bb = BYTEBUF_BLANK;
    bb.ptr = (char*)key;
    bb.len = key_len;
    return Hash_delete_bb(self, &bb);
}

void
Hash_iter_init(Hash *self) 
{
    HashEntry *next_entry;

    /* start at the last bucket and work backwards */
    self->iter_bucket = self->num_buckets - 1; 
    next_entry        = self->buckets[ self->iter_bucket ];

    while (next_entry == NULL) {
        /* kill iterator and bail if we've worked our way back to the top */
        if (self->iter_bucket == 0) {
            kill_iter(self);
            break;
        }
        else {
            self->iter_bucket--;
            next_entry = self->buckets[ self->iter_bucket ];
        }
    }

    self->next_entry = next_entry;
}

static void
kill_iter(Hash *self) 
{
    self->iter_bucket = 0;
    self->next_entry  = NULL;
}

bool_t
Hash_iter_next(Hash *self, ByteBuf **key, Obj **value) 
{
    HashEntry *this_entry = self->next_entry;
    HashEntry *next_entry;

    /* bail if we've completed the iteration or iter_init hasn't be called */
    if (this_entry == NULL) {
        kill_iter(self);
        *key = NULL;
        *value = NULL;
        return false;
    }

    /* find the next entry, if there is one */
    next_entry = this_entry->next;
    while (next_entry == NULL) {
        /* kill iterator and bail if we've worked our way back to the top */
        if (self->iter_bucket == 0) {
            kill_iter(self);
            break;
        }
        else {
            self->iter_bucket--;
            next_entry = self->buckets[ self->iter_bucket ];
        }
    }

    self->next_entry = next_entry;

    /* success! */
    *key = this_entry->key;
    *value = this_entry->value;
    return true;
}

ByteBuf*
Hash_find_key(Hash *self, const ByteBuf *key)
{
    i32_t hash_val = Obj_Hash_Code(key);
    HashEntry **bucket = self->buckets + (hash_val % self->num_buckets);

    if (*bucket != NULL) {
        HashEntry *entry = *bucket;
        for ( ; entry != NULL; entry = entry->next) {
            if (   entry->hash_val == hash_val
                && Obj_Equals(key, (Obj*)entry->key)
            ) {
                return entry->key;
            }
        }
    }

    /* failed to find the key, so return NULL */
    return NULL;
}

static Obj dummy_obj = { &OBJ, 1 };

ByteBuf*
Hash_add_key(Hash *self, const ByteBuf *key)
{
    ByteBuf *manufactured_key = Hash_Find_Key(self, key);
    if (manufactured_key == NULL) {
        Hash_Store_BB(self, key, &dummy_obj);
        manufactured_key = Hash_Find_Key(self, key);
    }
    return manufactured_key;
}

/* declare external symbols */
struct kino_VArray;
extern struct kino_VArray*
kino_VA_new(u32_t capacity);
extern void
kino_VA_push(struct kino_VArray *varray, Obj *elem);

struct kino_VArray*
Hash_keys(Hash *self) 
{
    ByteBuf *key;
    Obj *val;
    struct kino_VArray *keys = kino_VA_new(self->size);
    Hash_Iter_Init(self);
    while (Hash_Iter_Next(self, &key, &val)) {
        kino_VA_push(keys, (Obj*)key);
    }
    return keys;
}


static void 
rebuild_hash(Hash *self)
{
    HashEntry **old_buckets = self->buckets;
    HashEntry **old_buckets_limit = old_buckets + self->num_buckets;
    const u32_t num_buckets = self->num_buckets * 2;
    HashEntry **new_buckets = CALLOCATE(num_buckets, HashEntry*);
    
    kill_iter(self);

    for ( ; old_buckets < old_buckets_limit; old_buckets++) {
        HashEntry *entry = *old_buckets;
        while (entry != NULL) {
            HashEntry *const next_entry = entry->next;
            HashEntry **new_bucket 
                = new_buckets + (entry->hash_val % num_buckets);

            if (*new_bucket == NULL) {
                *new_bucket = entry;
            }
            else {
                HashEntry *collider = *new_bucket;
                while (collider->next != NULL) {
                    collider = collider->next;
                }
                collider->next = entry;
            }

            entry->next = NULL;
            entry = next_entry;
        }
    }

    free(self->buckets);
    self->buckets = new_buckets;
    self->num_buckets = num_buckets;
    self->threshold = num_buckets * 3 / 4;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

