#ifndef H_KINO_STRINGHELPER
#define H_KINO_STRINGHELPER 1

#include "charmony.h"
#include "boil.h"
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
kino_CharBuf*
kino_StrHelp_to_base36(chy_u32_t num);

/* A table where the values indicate the number of bytes in a UTF-8 sequence
 * implied by the leading utf8 byte.
 */
extern const chy_u8_t KINO_STRHELP_UTF8_SKIP[];

/* A table where the values indicate the number of trailing bytes in a UTF-8
 * sequence implied by the leading utf8 byte.
 */
extern const chy_u8_t KINO_STRHELP_UTF8_TRAILING[];

/** Return true if the string is valid UTF-8, false otherwise.
 */
chy_bool_t
kino_StrHelp_utf8_valid(const char *ptr, size_t len);

/* Returns true if the code point qualifies as Unicode whitespace.
 */
chy_bool_t
kino_StrHelp_is_whitespace(chy_u32_t code_point); 

/** Encode a Unicode code point to a UTF-8 sequence.  
 * 
 * @param code_point A legal unicode code point.
 * @param buf Write buffer which must hold at least 4 bytes (the maximum 
 * legal length for a UTF-8 char).
 */
chy_u32_t
kino_StrHelp_encode_utf8_char(chy_u32_t code_point, chy_u8_t *buf);

/* Decode a UTF-8 sequence to a Unicode code point.  Assumes valid UTF-8. 
 */
chy_u32_t
kino_StrHelp_decode_utf8_char(const char *utf8);

/* Return the first non-continuation byte before the supplied pointer.  If
 * backtracking progresses beyond the supplied start, return NULL. 
 */
const char*
kino_StrHelp_back_utf8_char(const char *utf8, char *start);

#ifdef KINO_USE_SHORT_NAMES
# define StrHelp_strndup            kino_StrHelp_strndup
# define StrHelp_string_diff        kino_StrHelp_string_diff
# define StrHelp_compare_strings    kino_StrHelp_compare_strings
# define StrHelp_to_base36          kino_StrHelp_to_base36
# define StrHelp_add_indent         kino_StrHelp_add_indent
# define UTF8_SKIP                  KINO_STRHELP_UTF8_SKIP
# define UTF8_TRAILING              KINO_STRHELP_UTF8_TRAILING
# define StrHelp_utf8_valid         kino_StrHelp_utf8_valid
# define StrHelp_is_whitespace      kino_StrHelp_is_whitespace
# define StrHelp_decode_utf8_char   kino_StrHelp_decode_utf8_char
# define StrHelp_encode_utf8_char   kino_StrHelp_encode_utf8_char
# define StrHelp_back_utf8_char     kino_StrHelp_back_utf8_char
#endif 

#endif /* H_KINO_STRINGHELPER */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

