#ifndef H_CHAZ
#define H_CHAZ 1

#include <stddef.h>
#include <stdio.h>

/* Set up the Charmonizer environment.  This should be called before anything
 * else.
 * 
 * @param os_name a lowercase string representing the operating system
 * @param cc_command the string used to invoke the C compiler via system()
 * @param cc_flags flags which will be passed on to the C compiler
 * @param charmony_start Code to prepend onto the front of charmony.h
 */
void
chaz_Probe_init(const char *os_name, const char *cc_command, 
                const char *cc_flags, const char *charmony_start);

/* Clean up the Charmonizer environment -- deleting tempfiles, etc.  This
 * should be called only after everything else finishes.
 */
void
chaz_Probe_clean_up();

/* Determine how much feedback Charmonizer provides.  
 * 0 - silent
 * 1 - normal
 * 2 - debugging
 */
void
chaz_Probe_set_verbosity(int level);

/* Read an entire file into memory.
 */
char*
chaz_Probe_slurp_file(char* filepath, size_t *len_ptr);

/* Access the FILE* used to write charmony.h, so that you can write your own
 * content to it.  Should not be called before chaz_Probe_init() or after
 * chaz_Probe_clean_up().
 */
FILE*
chaz_Probe_get_charmony_fh(void);

#endif /* include guard */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

