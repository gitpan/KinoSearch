/* Charmonizer/Probe/LargeFiles.h
 */

#ifndef H_CHAZ_LARGE_FILES
#define H_CHAZ_LARGE_FILES

#include <stdio.h>

/* The LargeFiles module attempts to detect these symbols or alias them to
 * synonyms:
 * 
 * off64_t
 * ftello64
 * fseeko64
 * 
 * If the attempt succeeds, this will be defined:
 * 
 * HAS_LARGE_FILE_SUPPORT
 * 
 * Use of the off64_t symbol may require sys/types.h.
 */
void chaz_LargeFiles_run(void);

#ifdef CHAZ_USE_SHORT_NAMES
  #define LargeFiles_run    chaz_LargeFiles_run
#endif

#endif /* H_CHAZ_LARGE_FILES */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

