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
    kino_u32_t                 num_buckets;
    kino_u32_t                 size;
    kino_u32_t                 threshold;    /* rehashing trigger point */
    struct kino_HashEntry     *next_entry;   /* used when iterating */
    kino_u32_t                 iter_bucket;  /* used when iterating */
};

/* Constructor.  [capacity] is the approximate number of elements that the hash
 * will be asked to hold (but not a limit).
 */
KINO_FUNCTION(
kino_Hash*
kino_Hash_new(kino_u32_t capacity));

/* Clear the hash of all key-value pairs.
 */
KINO_METHOD("Kino_Hash_Clear",
void
kino_Hash_clear(kino_Hash *self));

/* Store a value in the hash, with a key formed by creating a ByteBuf from
 * [str] and [len].
 *
 * If the key already exists, the new value will displace the old.
 */
KINO_METHOD("Kino_Hash_Store",
void
kino_Hash_store(kino_Hash *self, const char *str, size_t len, 
                    kino_Obj *value));

/* Store a key-value pair, using a copy of the ByteBuf as a key.
 */
KINO_METHOD("Kino_Hash_Store_BB",
void
kino_Hash_store_bb(kino_Hash *self, const kino_ByteBuf *key, kino_Obj *value));

/* Create a stringified ByteBuf version of [num] and store it in the hash.
 */
KINO_METHOD("Kino_Hash_Store_I64",
void
kino_Hash_store_i64(kino_Hash *self, const char *str, size_t key_len, 
                        kino_i64_t num));

/* Fetch the value associated with a given key.  If the key is not present,
 * NULL is returned.
 */
KINO_METHOD("Kino_Hash_Fetch_BB",
kino_Obj*
kino_Hash_fetch_bb(kino_Hash *self, const kino_ByteBuf *key));

/* Create a temporary ByteBuf key using [str] and [len], and attempt to fetch
 * a value using that.
 */
KINO_METHOD("Kino_Hash_Fetch",
kino_Obj*
kino_Hash_fetch(kino_Hash *self, const char *key, size_t key_len));

/* Use the supplied [str] and [len] to find a ByteBuf and convert it to a 64
 * bit integer.  Throw an error if key does not turn up a ByteBuf.
 */
KINO_METHOD("Kino_Hash_Fetch_I64",
kino_i64_t
kino_Hash_fetch_i64(kino_Hash *self, const char *key, size_t key_len));

/* Attempt to delete a key-value pair from the hash.  If the key exists and
 * the deletion is successful, return true.  If the key does not exist, return
 * false.
 */
KINO_METHOD("Kino_Hash_Delete_BB",
kino_bool_t
kino_Hash_delete_bb(kino_Hash *self, const kino_ByteBuf *key));

/* As Hash_delete_bb, above.
 */
KINO_METHOD("Kino_Hash_Delete",
kino_bool_t
kino_Hash_delete(kino_Hash *self, const char *key, size_t key_ley));

/* Prepare to iterate over all the key-value pairs in the hash.
 */
KINO_METHOD("Kino_Hash_Iter_Init",
void
kino_Hash_iter_init(kino_Hash *self));

/* Retrieve the next key-value pair from the hash, setting the supplied
 * pointers to point at them.  Returns false when the iterator has been
 * exhausted.
 */
KINO_METHOD("Kino_Hash_Iter_Next",
kino_bool_t
kino_Hash_iter_next(kino_Hash *self, kino_ByteBuf **key, kino_Obj **value));

/* Return an VArray of pointers to the hash's keys.
 */
KINO_METHOD("Kino_Hash_Keys",
struct kino_VArray*
kino_Hash_keys(kino_Hash *self));

KINO_METHOD("Kino_Hash_Destroy",
void 
kino_Hash_destroy(kino_Hash *self));

KINO_END_CLASS

#endif /* H_KINO_HASH */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

