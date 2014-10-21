#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestHash.h"
#include "KinoSearch/Util/Hash.h"
#include "KinoSearch/Obj/Undefined.h"
#include "KinoSearch/Util/Freezer.h"

static void
test_Equals(TestBatch *batch)
{
    Hash *hash  = Hash_new(0);
    Hash *other = Hash_new(0);

    ASSERT_TRUE(batch, Hash_Equals(hash, (Obj*)other), 
        "Empty hashes are equal");

    Hash_Store_Str(hash, "foo", 3, INCREF(&EMPTY));
    ASSERT_FALSE(batch, Hash_Equals(hash, (Obj*)other), 
        "Add one pair and Equals returns false");

    Hash_Store_Str(other, "foo", 3, INCREF(&EMPTY));
    ASSERT_TRUE(batch, Hash_Equals(hash, (Obj*)other), 
        "Add a matching pair and Equals returns true");

    Hash_Store_Str(other, "foo", 3, INCREF(UNDEF));
    ASSERT_FALSE(batch, Hash_Equals(hash, (Obj*)other), 
        "Non-matching value spoils Equals");

    DECREF(hash);
    DECREF(other);
}

static void
test_Store_and_Fetch(TestBatch *batch)
{
    Hash          *hash         = Hash_new(100);
    Hash          *dupe         = Hash_new(100);
    const u32_t    starting_cap = hash->capacity;
    VArray        *expected     = VA_new(100);
    VArray        *got          = VA_new(100);
    ZombieCharBuf  twenty       = ZCB_make_str("20", 2);
    ZombieCharBuf  forty        = ZCB_make_str("40", 2);
    ZombieCharBuf  foo          = ZCB_make_str("foo", 3);
    i32_t i;

    for (i = 0; i < 100; i++) {
        CharBuf *cb = CB_newf("%i32", i);
        Hash_Store(hash, cb, (Obj*)cb);
        Hash_Store(dupe, cb, INCREF(cb));
        VA_Push(expected, INCREF(cb));
    }
    ASSERT_TRUE(batch, Hash_Equals(hash, (Obj*)dupe), "Equals");

    ASSERT_INT_EQ(batch, hash->capacity, starting_cap, 
        "Initial capacity sufficient (no rebuilds)");

    for (i = 0; i < 100; i++) {
        CharBuf *key = (CharBuf*)VA_Fetch(expected, i);
        Obj *elem = Hash_Fetch(hash, key);
        VA_Push(got, (Obj*)INCREF(elem));
    }

    ASSERT_TRUE(batch, VA_Equals(got, (Obj*)expected), 
        "basic Store and Fetch");
    ASSERT_INT_EQ(batch, Hash_Get_Size(hash), 100, 
        "size incremented properly by Hash_Store");

    ASSERT_TRUE(batch, Hash_Fetch(hash, (CharBuf*)&foo) == NULL, 
        "Fetch against non-existent key returns NULL");

    Hash_Store(hash, (CharBuf*)&forty, INCREF(&foo));
    ASSERT_TRUE(batch, Hash_Equals(&foo, Hash_Fetch(hash, (CharBuf*)&forty)),
        "Hash_Store replaces existing value");
    ASSERT_FALSE(batch, Hash_Equals(hash, (Obj*)dupe), 
        "replacement value spoils equals");
    ASSERT_INT_EQ(batch, Hash_Get_Size(hash), 100, 
        "size unaffected after value replaced");

    ASSERT_TRUE(batch, Hash_Delete(hash, (CharBuf*)&forty) == (Obj*)&foo, 
        "Delete returns value");
    DECREF(&foo);
    ASSERT_INT_EQ(batch, Hash_Get_Size(hash), 99, 
        "size decremented by successful Delete");
    ASSERT_TRUE(batch, Hash_Delete(hash, (CharBuf*)&forty) == NULL, 
        "Delete returns NULL when key not found");
    ASSERT_INT_EQ(batch, Hash_Get_Size(hash), 99, 
        "size not decremented by unsuccessful Delete");
    DECREF(Hash_Delete(dupe, (CharBuf*)&forty));
    ASSERT_TRUE(batch, VA_Equals(got, (Obj*)expected), "Equals after Delete");

    Hash_Clear(hash);
    ASSERT_TRUE(batch, Hash_Fetch(hash, (CharBuf*)&twenty) == NULL, "Clear");
    ASSERT_TRUE(batch, Hash_Get_Size(hash) == 0, "size is 0 after Clear");

    DECREF(hash);
    DECREF(dupe);
    DECREF(got);
    DECREF(expected);
}

static void
test_Keys_Values_Iter(TestBatch *batch)
{
    u32_t i;
    Hash     *hash         = Hash_new(0); /* trigger multiple rebuilds. */
    VArray   *expected     = VA_new(100);
    VArray   *keys;
    VArray   *values;

    for (i = 0; i < 500; i++) {
        CharBuf *cb = CB_newf("%u32", i);
        Hash_Store(hash, cb, (Obj*)cb);
        VA_Push(expected, INCREF(cb));
    }

    VA_Sort(expected, NULL);

    /* Overwrite for good measure. */
    for (i = 0; i < 500; i++) {
        CharBuf *cb = (CharBuf*)VA_Fetch(expected, i);
        Hash_Store(hash, cb, INCREF(cb));
    }

    keys   = Hash_Keys(hash);
    values = Hash_Values(hash);
    VA_Sort(keys, NULL);
    VA_Sort(values, NULL);
    ASSERT_TRUE(batch, VA_Equals(keys, (Obj*)expected), "Keys");
    ASSERT_TRUE(batch, VA_Equals(values, (Obj*)expected), "Values");
    VA_Clear(keys);
    VA_Clear(values);
    
    {
        CharBuf *key;
        Obj     *value;
        Hash_Iter_Init(hash);
        while (Hash_Iter_Next(hash, &key, &value)) {
            VA_Push(keys, INCREF(key));
            VA_Push(values, INCREF(value));
        }
    }

    VA_Sort(keys, NULL);
    VA_Sort(values, NULL);
    ASSERT_TRUE(batch, VA_Equals(keys, (Obj*)expected), "Keys from Iter");
    ASSERT_TRUE(batch, VA_Equals(values, (Obj*)expected), "Values from Iter");

    {
        ZombieCharBuf forty = ZCB_make_str("40", 2);
        ZombieCharBuf nope  = ZCB_make_str("nope", 4);
        CharBuf *key 
            = Hash_Find_Key(hash, (CharBuf*)&forty, ZCB_Hash_Code(&forty));
        ASSERT_TRUE(batch, CB_Equals(key, (Obj*)&forty), "Find_Key");
        key = Hash_Find_Key(hash, (CharBuf*)&nope, ZCB_Hash_Code(&nope)),
        ASSERT_TRUE(batch, key == NULL, 
            "Find_Key returns NULL for non-existent key");
    }

    DECREF(hash);
    DECREF(expected);
    DECREF(keys);
    DECREF(values);
}

static void
test_Dump_and_Load(TestBatch *batch)
{
    Hash *hash = Hash_new(0);
    Obj  *dump;
    Hash *loaded;

    Hash_Store_Str(hash, "foo", 3,
        (Obj*)CB_new_from_trusted_utf8("foo", 3));
    dump = (Obj*)Hash_Dump(hash);
    loaded = (Hash*)Obj_Load(dump, dump);
    ASSERT_TRUE(batch, Hash_Equals(hash, (Obj*)loaded), 
        "Dump => Load round trip");
    DECREF(dump);
    DECREF(loaded);

    /* TODO: Fix Hash_Load().

    Hash_Store_Str(hash, "_class", 6,
        (Obj*)CB_new_from_trusted_utf8("not_a_class", 11));
    dump = (Obj*)Hash_Dump(hash);
    loaded = (Hash*)Obj_Load(dump, dump);

    ASSERT_TRUE(batch, Hash_Equals(hash, (Obj*)loaded), 
        "Load still works with _class if it's not a real class");
    DECREF(dump);
    DECREF(loaded);

    */

    DECREF(hash);
}


void
TestHash_run_tests()
{
    TestBatch *batch = Test_new_batch("TestHash", 26, NULL);

    PLAN(batch);

    test_Equals(batch);
    test_Store_and_Fetch(batch);
    test_Keys_Values_Iter(batch);
    test_Dump_and_Load(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

