/** 
 * @class KinoSearch::Util::ByteBuf ByteBuf.r
 * @brief Growable buffer holding arbitrary bytes. 
 *
 * The ByteBuf is a C struct that's essentially a growable string of char.
 * It's like a stripped down Perl scalar that can only deal with strings.  It
 * knows its own size and capacity, so it can contain arbitrary binary data.  
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
kino_ByteBuf*
kino_BB_new(size_t future_size);

/* Return a pointer to a new ByteBuf which holds a copy of the passed-in
 * string.
 */
kino_ByteBuf*
kino_BB_new_str(const char *ptr, size_t size);

/* Return a pointer to a new ByteBuf which assumes ownership of the passed-in 
 * string.
 */
kino_ByteBuf*
kino_BB_new_steal(char *ptr, size_t len, size_t cap);

/* Return a pointer to a new ByteBuf which contains a stringified version of
 * [num].
 */
kino_ByteBuf*
kino_BB_new_i64(chy_i64_t num);

/* Lexical comparison of two ByteBufs, with level of indirection set to please
 * qsort and friends.
 */
int 
kino_BB_compare(const void *va, const void *vb); 

/* Version of less_than to pass to PriorityQueue.
 */
chy_bool_t
kino_BB_less_than(const void *va, const void *vb); 

/* Deserialize a serialized ByteBuf.  Consume characters in the ViewByteBuf.
 */
kino_ByteBuf*
kino_BB_deserialize(struct kino_ViewByteBuf *serialized);

/* Copy the passed-in string into the ByteBuf.  Allocate more memory if
 * necessary. 
 */
void
kino_BB_copy_str(kino_ByteBuf *self, char* ptr, size_t size);
KINO_METHOD("Kino_BB_Copy_Str");

/* Copy the contents of the passed-in string into the original ByteBuf.  
 * Allocate more memory if necessary. 
 */
void
kino_BB_copy_bb(kino_ByteBuf *self, const kino_ByteBuf *other);
KINO_METHOD("Kino_BB_Copy_BB");

/* Concatenate the passed-in string onto the end of the ByteBuf. Allocate more
 * memory as needed.
 */
void 
kino_BB_cat_str(kino_ByteBuf *self, char* ptr, size_t size);
KINO_METHOD("Kino_BB_Cat_Str");

/* Concatenate the contents of the passed-in ByteBuf onto the end of the
 * original ByteBuf. Allocate more memory as needed.
 */
void 
kino_BB_cat_bb(kino_ByteBuf *self, const kino_ByteBuf *other);
KINO_METHOD("Kino_BB_Cat_BB");

/* Concatenate the stringified form of [num] onto the end of the ByteBuf.
 */
void
kino_BB_cat_i64(kino_ByteBuf *self, chy_i64_t num);
KINO_METHOD("Kino_BB_Cat_I64");

/* Extract an integer from the stringified version held in the ByteBuf.  
 */
chy_i64_t
kino_BB_to_i64(kino_ByteBuf *self);
KINO_METHOD("Kino_BB_To_I64");

/* Assign more memory to the ByteBuf, if it doesn't already have enough room
 * to hold a string of [size] bytes.  Cannot shrink the allocation.
 */
void 
kino_BB_grow(kino_ByteBuf *self, size_t new_size);
KINO_METHOD("Kino_BB_Grow");

/* Test whether the ByteBuf starts with the content of another.
 */
chy_bool_t
kino_BB_starts_with(kino_ByteBuf *self, const kino_ByteBuf *prefix);
KINO_METHOD("Kino_BB_Starts_With");

/* Test whether the ByteBuf ends with the content of another.
 */
chy_bool_t
kino_BB_ends_with_str(kino_ByteBuf *self, const char *postfix, 
                      size_t postfix_len);
KINO_METHOD("Kino_BB_Ends_With_Str");

kino_ByteBuf*
kino_BB_clone(kino_ByteBuf *self);
KINO_METHOD("Kino_BB_Clone");

void
kino_BB_destroy(kino_ByteBuf *self);
KINO_METHOD("Kino_BB_Destroy");

chy_bool_t
kino_BB_equals(kino_ByteBuf *self, kino_ByteBuf *other);
KINO_METHOD("Kino_BB_Equals");

chy_i32_t
kino_BB_hash_code(kino_ByteBuf *self);
KINO_METHOD("Kino_BB_Hash_Code");

kino_ByteBuf*
kino_BB_to_string(kino_ByteBuf *self);
KINO_METHOD("Kino_BB_To_String");

void
kino_BB_serialize(kino_ByteBuf *self, kino_ByteBuf *target);
KINO_METHOD("Kino_BB_Serialize");

KINO_END_CLASS

#define KINO_BB_GROW(self, new_len) \
    do { \
        if (new_len >= self->cap) \
            BB_grow(self, new_len); \
    } while (0)

#define KINO_BYTEBUF_BLANK { &KINO_BYTEBUF, 0, "", 0, 0 }
#define KINO_BBEND(self) ((self)->ptr + (self)->len)
#define KINO_BB_CLONE(self) ((kino_ByteBuf*)Kino_Obj_Clone(self))
#define KINO_BB_LITERAL(string) \
    { &KINO_BYTEBUF, 0, string "", sizeof(string) -1, sizeof(string) }

#ifdef KINO_USE_SHORT_NAMES
  #define BB_GROW(self, len)  KINO_BB_GROW(self, len)
  #define BYTEBUF_BLANK       KINO_BYTEBUF_BLANK
  #define BBEND(self)         KINO_BBEND(self)
  #define BB_CLONE(self)      KINO_BB_CLONE(self)
  #define BB_LITERAL(string)  KINO_BB_LITERAL(string)
#endif

#endif /* H_KINO_BYTEBUF */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

