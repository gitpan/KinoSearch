#ifndef H_KINO_MEMMANAGER
#define H_KINO_MEMMANAGER 1

/** Attempt to allocate memory with malloc, but print an error and exit if the
 * call fails.
 */
void*
kino_MemMan_wrapped_malloc(size_t count);

/** Attempt to allocate memory with calloc, but print an error and exit if the
 * call fails.
 */
void*
kino_MemMan_wrapped_calloc(size_t count, size_t size);

/** Attempt to allocate memory with realloc, but print an error and exit if 
 * the call fails.
 */
void*
kino_MemMan_wrapped_realloc(void *ptr, size_t size);

/** Free memory.  (Wrapping is necessary in cases where memory allocated
 * within the KinoSearch library has to freed in an external environment where
 * "free" may have been redefined.)
 */
void
kino_MemMan_wrapped_free(void *ptr);

#define KINO_MALLOCATE(n,t) \
    (t*)kino_MemMan_wrapped_malloc((n)*sizeof(t))
#define KINO_CALLOCATE(n,t) \
    (t*)kino_MemMan_wrapped_calloc((n),sizeof(t))
#define KINO_REALLOCATE(v,n,t) \
    (t*)kino_MemMan_wrapped_realloc((v), (n)*sizeof(t))

#ifdef KINO_USE_SHORT_NAMES
  #define MemMan_wrapped_malloc           kino_MemMan_wrapped_malloc
  #define MemMan_wrapped_calloc           kino_MemMan_wrapped_calloc
  #define MemMan_wrapped_realloc          kino_MemMan_wrapped_realloc
  #define MemMan_wrapped_free             kino_MemMan_wrapped_free
  #define MALLOCATE(n,t)                  KINO_MALLOCATE(n,t)
  #define CALLOCATE(n,t)                  KINO_CALLOCATE(n,t)
  #define REALLOCATE(v,n,t)               KINO_REALLOCATE(v,n,t)
#endif

#endif /* H_KINO_MEMMANAGER */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

