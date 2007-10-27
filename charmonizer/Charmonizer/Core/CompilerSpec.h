/* Charmonizer/CompilerSpec.h
 */

#ifndef H_CHAZ_COMPILER_SPEC
#define H_CHAZ_COMPILER_SPEC

#include <stddef.h>
#include "Charmonizer/Core/Defines.h"

typedef struct chaz_CompilerSpec chaz_CompilerSpec;

struct chaz_CompilerSpec {
    char *nickname;
    char *include_flag;
    char *object_flag;
    char *exe_flag;
};

/* Detect a supported compiler and return its profile.
 */
chaz_CompilerSpec*
chaz_CCSpec_find_spec();

#ifdef CHAZ_USE_SHORT_NAMES
  #define CompilerSpec                chaz_CompilerSpec
  #define CCSpec_find_spec            chaz_CCSpec_find_spec
#endif

#endif /* H_CHAZ_COMPILER_SPEC */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

