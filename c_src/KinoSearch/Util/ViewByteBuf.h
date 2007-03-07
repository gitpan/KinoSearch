/* KinoSearch/Util/ByteBuf.h -- stripped down scalar
 *
 * The ByteBuf is a C struct that's essentially a growable string of char.
 * It's like a stripped down scalar that can only deal with strings.  It knows
 * its own size and capacity, so it can contain arbitrary binary data.  
 * 
 * "View" ByteBufs don't own their own strings.  
 */ 

#ifndef H_KINO_VIEWBYTEBUF
#define H_KINO_VIEWBYTEBUF 1

#include <stddef.h>
#include "KinoSearch/Util/ByteBuf.r"

typedef struct kino_ViewByteBuf kino_ViewByteBuf;
typedef struct KINO_VIEWBYTEBUF_VTABLE KINO_VIEWBYTEBUF_VTABLE;

KINO_CLASS("KinoSearch::Util::ViewByteBuf", "ViewBB",
    "KinoSearch::Util::ByteBuf");

struct kino_ViewByteBuf {
    KINO_VIEWBYTEBUF_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    char       *ptr;
    size_t      len;  /* number of valid chars */
    size_t      cap;  /* allocated bytes, including any null termination */
};

/* Return a pointer to a new "view" ByteBuf, offing a persective on the 
 * passed-in string.
 */
KINO_FUNCTION(
kino_ViewByteBuf*
kino_ViewBB_new(char *ptr, size_t size));

/* Assign the ptr and size members to the passed in values.  Downgrade the
 * ByteBuf to a "view" ByteBuf and free any existing assigned memory if
 * necessary.
 */
KINO_METHOD("Kino_ViewBB_Assign",
void
kino_ViewBB_assign(kino_ViewByteBuf *self, char*ptr, size_t size));

KINO_METHOD("Kino_ViewBB_Destroy",
void
kino_ViewBB_destroy(kino_ViewByteBuf *self));

KINO_END_CLASS

#endif /* H_KINO_VIEWBYTEBUF */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

