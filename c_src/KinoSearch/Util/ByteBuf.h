/* KinoSearch/Util/ByteBuf.h -- stripped down scalar
 *
 * The ByteBuf is a C struct that's essentially a growable string of char.
 * It's like a stripped down scalar that can only deal with strings.  It knows
 * its own size and capacity, so it can contain arbitrary binary data.  
 */ 

#ifndef H_KINO_BYTEBUF
#define H_KINO_BYTEBUF 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"

typedef struct kino_ByteBuf kino_ByteBuf;
typedef struct KINO_BYTEBUF_VTABLE KINO_BYTEBUF_VTABLE;

struct kino_ViewByteBuf;

KINO_CLASS("KinoSearch::Util::ByteBuf", "BB", "KinoSearch::Util::Obj");

struct kino_ByteBuf {
    KINO_BYTEBUF_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    char       *ptr;
    size_t      len; /* number of valid chars */
    size_t      cap;  /* allocated bytes, including any null termination */
};

/* Return a pointer to a new ByteBuf with a capacity of [future_size] + 1
 * bytes.  Size is initialized to 0.  The first byte is set to NULL, so the
 * ByteBuf has an initial value of "".  None of the remaining allocated memory
 * is initialized.
 */
KINO_FUNCTION(
kino_ByteBuf*
kino_BB_new(size_t future_size));

/* Return a pointer to a new ByteBuf which holds a copy of the passed-in
 * string.
 */
KINO_FUNCTION(
kino_ByteBuf*
kino_BB_new_str(const char *ptr, size_t size));

/* Return a pointer to a new ByteBuf which assumes ownership of the passed-in 
 * string.
 */
KINO_FUNCTION(
kino_ByteBuf*
kino_BB_new_steal(char *ptr, size_t len, size_t cap));

/* Return a pointer to a new ByteBuf which contains a stringified version of
 * [num].
 */
KINO_FUNCTION(
kino_ByteBuf*
kino_BB_new_i64(kino_i64_t num));

/* Lexical comparison of two ByteBufs, with level of indirection set to please
 * qsort and friends.
 */
KINO_FUNCTION(
int 
kino_BB_compare(const void *va, const void *vb)); 

/* Version of less_than to pass to PriorityQueue.
 */
KINO_FUNCTION(
kino_bool_t
kino_BB_less_than(const void *va, const void *vb)); 

/* Deserialize a serialized ByteBuf.  Consume characters in the ViewByteBuf.
 */
KINO_FUNCTION(
kino_ByteBuf*
kino_BB_deserialize(struct kino_ViewByteBuf *serialized));

/* Copy the passed-in string into the ByteBuf.  Allocate more memory if
 * necessary. 
 */
KINO_METHOD("Kino_BB_Copy_Str",
void
kino_BB_copy_str(kino_ByteBuf *self, char* ptr, size_t size));

/* Copy the contents of the passed-in string into the original ByteBuf.  
 * Allocate more memory if necessary. 
 */
KINO_METHOD("Kino_BB_Copy_BB",
void
kino_BB_copy_bb(kino_ByteBuf *self, const kino_ByteBuf *other));

/* Concatenate the passed-in string onto the end of the ByteBuf. Allocate more
 * memory as needed.
 */
KINO_METHOD("Kino_BB_Cat_Str",
void 
kino_BB_cat_str(kino_ByteBuf *self, char* ptr, size_t size));

/* Concatenate the contents of the passed-in ByteBuf onto the end of the
 * original ByteBuf. Allocate more memory as needed.
 */
KINO_METHOD("Kino_BB_Cat_BB",
void 
kino_BB_cat_bb(kino_ByteBuf *self, const kino_ByteBuf *other));

/* Concatenate the stringified form of [num] onto the end of the ByteBuf.
 */
KINO_METHOD("Kino_BB_Cat_I64",
void
kino_BB_cat_i64(kino_ByteBuf *self, kino_i64_t num));

/* Extract an integer from the stringified version held in the ByteBuf.  
 */
KINO_METHOD("Kino_BB_To_I64",
kino_i64_t
kino_BB_to_i64(kino_ByteBuf *self));

/* Assign more memory to the ByteBuf, if it doesn't already have enough room
 * to hold a string of [size] bytes.  Cannot shrink the allocation.
 */
KINO_METHOD("Kino_BB_Grow",
void 
kino_BB_grow(kino_ByteBuf *self, size_t new_size));



KINO_METHOD("Kino_BB_Clone",
kino_ByteBuf*
kino_BB_clone(kino_ByteBuf *self));

KINO_METHOD("Kino_BB_Destroy",
void
kino_BB_destroy(kino_ByteBuf *self));

KINO_METHOD("Kino_BB_Equals",
kino_bool_t
kino_BB_equals(kino_ByteBuf *self, kino_ByteBuf *other)); 

KINO_METHOD("Kino_BB_Hash_Code",
kino_i32_t
kino_BB_hash_code(kino_ByteBuf *self));

KINO_METHOD("Kino_BB_To_String",
kino_ByteBuf*
kino_BB_to_string(kino_ByteBuf *self));

KINO_METHOD("Kino_BB_Serialize",
void
kino_BB_serialize(kino_ByteBuf *self, kino_ByteBuf *target));

KINO_END_CLASS

#define KINO_BYTEBUF_BLANK { &KINO_BYTEBUF, 0, "", 0, 0 }
#define KINO_BBEND(_bytebuf) ((_bytebuf)->ptr + (_bytebuf)->len)
#define KINO_BB_CLONE(_bytebuf) ((kino_ByteBuf*)Kino_Obj_Clone(_bytebuf))

#ifdef KINO_USE_SHORT_NAMES
  #define ByteBuf             kino_ByteBuf
  #define BYTEBUF_BLANK       KINO_BYTEBUF_BLANK
  #define BBEND(_bytebuf)     KINO_BBEND(_bytebuf)
  #define BB_CLONE(_bytebuf)  KINO_BB_CLONE(_bytebuf)
#endif

#endif /* H_KINO_BYTEBUF */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

