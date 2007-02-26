#define CHAZ_USE_SHORT_NAMES

#include <string.h>
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Core/CompilerSpec.h"

/* detect a supported compiler */
#ifdef __GNUC__
    static CompilerSpec spec = { "gcc", "-I ", "-o ", "-o " };
#elif defined(_MSC_VER)
    static CompilerSpec spec = { "MSVC", "/I", "/Fo", "/Fe" };
#else
  #error "Couldn't detect a supported compiler"
#endif


chaz_CompilerSpec*
chaz_CCSpec_find_spec()
{
    if (verbosity)
        printf("Trying to find a supported compiler...\n");

    return &spec;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

