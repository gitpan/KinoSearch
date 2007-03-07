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
    char       *mode;
    kino_u64_t  pos;
    kino_i32_t  stream_count;
};

/* Abstract method.  Seek FileDes to [target].
 */
KINO_METHOD("Kino_FileDes_FDSeek",
void
kino_FileDes_fdseek(kino_FileDes *self, kino_u64_t target));

/* Abstract method.  Read [len] bytes into [dest], starting after
 * [dest_offset] bytes.
 */
KINO_METHOD("Kino_FileDes_FDRead",
void
kino_FileDes_fdread(kino_FileDes *self, char *dest, kino_u32_t dest_offset, 
                    kino_u32_t len));

/* Abstract method.  Write buffer to target.
 */
KINO_METHOD("Kino_FileDes_FDWrite",
void
kino_FileDes_fdwrite(kino_FileDes *self, char* buf, kino_u32_t len));

/* Abstract method.  Return the current length of the file in bytes.
 */
KINO_METHOD("Kino_FileDes_FDLength",
kino_u64_t 
kino_FileDes_fdlength(kino_FileDes *self));

/* Abstract method. Close the stream, releasing resources.
 */
KINO_METHOD("Kino_FileDes_FDClose",
void
kino_FileDes_fdclose(kino_FileDes *self));

KINO_END_CLASS

/* Integer which is incremented each time a FileDes is created and decremented
 * when a FileDes is destroyed.  Since so many classes use FileDes objects,
 * they're the canary in the coal mine for detecting object-destruction memory
 * leaks.
 */
extern kino_i32_t kino_FileDes_global_count; 

/* Size of the memory buffer used by both InStream and OutStream.
 */
#define KINO_IO_STREAM_BUF_SIZE 1024

#ifdef KINO_USE_SHORT_NAMES
  #define FileDes_global_count        kino_FileDes_global_count
  #define IO_STREAM_BUF_SIZE          KINO_IO_STREAM_BUF_SIZE
#endif

#endif /* H_KINO_FILEDES */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

