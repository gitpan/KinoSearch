#ifndef H_KINO_HASH
#define H_KINO_HASH 1

#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/ByteBuf.r"

typedef struct kino_Hash kino_Hash;
typedef struct KINO_HASH_VTABLE KINO_HASH_VTABLE;
typedef struct kino_HashEntry kino_HashEntry;

KINO_CLASS("KinoSearch::Util::Hash", "Hash", "KinoSearch::Util::Obj");

struct kino_Hash {
    KINO_HASH_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_HashEntry    **buckets;
    chy_u32_t                  num_buckets;
    chy_u32_t                  size;
    chy_u32_t                  threshold;    /* rehashing trigger point */
    struct kino_HashEntry     *next_entry;   /* used when iterating */
    chy_u32_t                  iter_bucket;  /* used when iterating */
};

/* Constructor.  [capacity] is the approximate number of elements that the
 * hash will be asked to hold (but not a limit).
 */
kino_Hash*
kino_Hash_new(chy_u32_t capacity);

/* Clear the hash of all key-value pairs.
 */
void
kino_Hash_clear(kino_Hash *self);
KINO_METHOD("Kino_Hash_Clear");

/* Store a value in the hash, with a key formed by creating a ByteBuf from
 * [str] and [len].
 *
 * If the key already exists, the new value will displace the old.
 */
void
kino_Hash_store(kino_Hash *self, const char *str, size_t len, 
                    kino_Obj *value);
KINO_METHOD("Kino_Hash_Store");

/* Store a key-value pair, using a copy of the ByteBuf as a key.
 */
void
kino_Hash_store_bb(kino_Hash *self, const kino_ByteBuf *key, kino_Obj *value);
KINO_METHOD("Kino_Hash_Store_BB");

/* Create a stringified ByteBuf version of [num] and store it in the hash.
 */
void
kino_Hash_store_i64(kino_Hash *self, const char *str, size_t key_len, 
                        chy_i64_t num);
KINO_METHOD("Kino_Hash_Store_I64");

/* Fetch the value associated with a given key.  If the key is not present,
 * NULL is returned.
 */
kino_Obj*
kino_Hash_fetch_bb(kino_Hash *self, const kino_ByteBuf *key);
KINO_METHOD("Kino_Hash_Fetch_BB");

/* Create a temporary ByteBuf key using [str] and [len], and attempt to fetch
 * a value using that.
 */
kino_Obj*
kino_Hash_fetch(kino_Hash *self, const char *key, size_t key_len);
KINO_METHOD("Kino_Hash_Fetch");

/* Use the supplied [str] and [len] to find a ByteBuf and convert it to a 64
 * bit integer.  Throw an error if key does not turn up a ByteBuf.
 */
chy_i64_t
kino_Hash_fetch_i64(kino_Hash *self, const char *key, size_t key_len);
KINO_METHOD("Kino_Hash_Fetch_I64");

/* Attempt to delete a key-value pair from the hash.  If the key exists and
 * the deletion is successful, return true.  If the key does not exist, return
 * false.
 */
chy_bool_t
kino_Hash_delete_bb(kino_Hash *self, const kino_ByteBuf *key);
KINO_METHOD("Kino_Hash_Delete_BB");

/* As Hash_delete_bb, above.
 */
chy_bool_t
kino_Hash_delete(kino_Hash *self, const char *key, size_t key_ley);
KINO_METHOD("Kino_Hash_Delete");

/* Prepare to iterate over all the key-value pairs in the hash.
 */
void
kino_Hash_iter_init(kino_Hash *self);
KINO_METHOD("Kino_Hash_Iter_Init");

/* Retrieve the next key-value pair from the hash, setting the supplied
 * pointers to point at them.  Returns false when the iterator has been
 * exhausted.
 */
chy_bool_t
kino_Hash_iter_next(kino_Hash *self, kino_ByteBuf **key, kino_Obj **value);
KINO_METHOD("Kino_Hash_Iter_Next");

/* Enables behavior mimicing a HashSet. Check for a key; if it's not there,
 * add it in conjunction with a dummy object.  Return the manufactured key.
 */
kino_ByteBuf*
kino_Hash_add_key(kino_Hash *self, const kino_ByteBuf *key);
KINO_METHOD("Kino_Hash_Add_Key");

/* Search for a key which Equals the key supplied, and return the key rather
 * than its value.
 */
kino_ByteBuf*
kino_Hash_find_key(kino_Hash *self, const kino_ByteBuf *key);
KINO_METHOD("Kino_Hash_Find_Key");

/* Return an VArray of pointers to the hash's keys.
 */
struct kino_VArray*
kino_Hash_keys(kino_Hash *self);
KINO_METHOD("Kino_Hash_Keys");

void 
kino_Hash_destroy(kino_Hash *self);
KINO_METHOD("Kino_Hash_Destroy");

KINO_END_CLASS

#endif /* H_KINO_HASH */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

