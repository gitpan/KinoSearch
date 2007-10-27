#ifndef H_KINO_STRINGHELPER
#define H_KINO_STRINGHELPER 1

#include "charmony.h"
#include <stddef.h>

char*
kino_StrHelp_strndup(const char *source, size_t len);

/* Return the number of bytes that two strings have in common.
 */
chy_i32_t
kino_StrHelp_string_diff(const char *a, const char *b, 
                         size_t a_len,  size_t b_len);

/* memcmp, but with lengths for both pointers, not just one.
 */
chy_i32_t
kino_StrHelp_compare_strings(const char *a, const char *b, 
                             size_t a_len,  size_t b_len);

/* Return a string representation of a number in base 36.
 */
struct kino_ByteBuf*
kino_StrHelp_to_base36(chy_u32_t num);

/* Add [amount] spaces at the start of the string and after each newline.
 */
void
kino_StrHelp_add_indent(struct kino_ByteBuf *bb, size_t amount);

/* A table of unsigned char, with the number of bytes indicated by a leading
 * utf8 byte.
 */
extern const chy_u8_t KINO_STRHELP_UTF8_SKIP[];

#ifdef KINO_USE_SHORT_NAMES
# define StrHelp_strndup            kino_StrHelp_strndup
# define StrHelp_string_diff        kino_StrHelp_string_diff
# define StrHelp_compare_strings    kino_StrHelp_compare_strings
# define StrHelp_to_base36          kino_StrHelp_to_base36
# define StrHelp_add_indent         kino_StrHelp_add_indent
# define UTF8_SKIP                  KINO_STRHELP_UTF8_SKIP
#endif 

#endif /* H_KINO_STRINGHELPER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

