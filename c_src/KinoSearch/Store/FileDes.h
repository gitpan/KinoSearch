#ifndef H_KINO_FILEDES
#define H_KINO_FILEDES 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_FileDes kino_FileDes;
typedef struct KINO_FILEDES_VTABLE KINO_FILEDES_VTABLE;

KINO_CLASS("KinoSearch::Store::FileDes", "FileDes", "KinoSearch::Util::Obj");

struct kino_FileDes {
    KINO_FILEDES_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    char       *path;
    chy_u64_t   pos;
    chy_i32_t   stream_count;
};

/* Abstract method.  Seek FileDes to [target].
 *
 * @returns true on success, false on failure (sets kerror)
 */
chy_bool_t
kino_FileDes_fdseek(kino_FileDes *self, chy_u64_t target);
KINO_METHOD("Kino_FileDes_FDSeek");

/* Abstract method.  Read [len] bytes into [dest], starting after
 * [dest_offset] bytes.
 *
 * @returns true on success, false on failure (sets kerror)
 */
chy_bool_t
kino_FileDes_fdread(kino_FileDes *self, char *dest, chy_u32_t dest_offset, 
                    chy_u32_t len);
KINO_METHOD("Kino_FileDes_FDRead");

/* Abstract method.  Write buffer to target.
 *
 * @returns true on success, false on failure (sets kerror)
 */
chy_bool_t
kino_FileDes_fdwrite(kino_FileDes *self, const char* buf, chy_u32_t len);
KINO_METHOD("Kino_FileDes_FDWrite");

/* Abstract method.  Return the current length of the file in bytes.
 */
chy_u64_t 
kino_FileDes_fdlength(kino_FileDes *self);
KINO_METHOD("Kino_FileDes_FDLength");

/* Abstract method. Close the stream, releasing resources.
 *
 * @returns true on success, false on failure (sets kerror)
 */
chy_bool_t
kino_FileDes_fdclose(kino_FileDes *self);
KINO_METHOD("Kino_FileDes_FDClose");

KINO_END_CLASS

/* Integer which is incremented each time a FileDes is created and decremented
 * when a FileDes is destroyed.  Since so many classes use FileDes objects,
 * they're the canary in the coal mine for detecting object-destruction memory
 * leaks.
 */
extern chy_i32_t kino_FileDes_object_count; 

/* Similar to above, but incremented upon successful open and decremented on
 * successful close
 */
extern chy_i32_t kino_FileDes_open_count; 

/* Size of the memory buffer used by both InStream and OutStream.
 */
#define KINO_IO_STREAM_BUF_SIZE 1024

#ifdef KINO_USE_SHORT_NAMES
  #define FileDes_object_count        kino_FileDes_object_count
  #define FileDes_open_count          kino_FileDes_open_count
  #define IO_STREAM_BUF_SIZE          KINO_IO_STREAM_BUF_SIZE
#endif

#endif /* H_KINO_FILEDES */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

