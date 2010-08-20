#include "xs/XSBind.h"
#include "KinoSearch/Util/StringHelper.h"

chy_bool_t
kino_StrHelp_utf8_valid(const char *ptr, size_t size)
{
    return is_utf8_string((const U8*)ptr, size);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

