#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Util/Err.h"
#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Util/CharBuf.h"

/* Fallbacks in case variadic macros aren't available. */
#ifndef CHY_HAS_VARIADIC_MACROS
void
THROW(char *pattern, ...)
{
    va_list args;
    CharBuf *const message = CB_new(strlen(pattern) + 10);

    va_start(args, pattern);
    CB_VCatF(message, pattern, args);
    va_end(args);

    Err_throw_mess(message);
}
void
KINO_WARN(char *pattern, ...)
{
    va_list args;
    CharBuf *const message = CB_new(strlen(pattern) + 10);

    va_start(args, pattern);
    CB_VCatF(message, pattern, args);
    va_end(args);

    Err_warn_mess(message);
}
CharBuf*
KINO_MAKE_MESS(char *pattern, ...)
{
    va_list args;
    CharBuf *const message = CB_new(strlen(pattern) + 10);

    va_start(args, pattern);
    CB_VCatF(message, pattern, args);
    va_end(args);

    return message;
}
#endif


static void
S_vcat_mess(CharBuf *message, const char *file, int line, const char *func, 
            const char *pattern, va_list args)
{
    size_t guess_len = strlen(file) 
                     + func ? strlen(func) : 0 
                     + strlen(pattern) 
                     + 30;
    CB_Grow(message, guess_len);
    CB_VCatF(message, pattern, args);
    if (func != NULL)
        CB_catf(message, " at %s:%i32 %s ", file, (i32_t)line, func);
    else 
        CB_catf(message, " at %s:%i32", file, (i32_t)line);
}

CharBuf*
Err_make_mess(const char *file, int line, const char *func, 
               const char *pattern, ...)
{
    va_list args;
    size_t guess_len = strlen(pattern) + strlen(file) + 20;
    CharBuf *message = CB_new(guess_len);
    va_start(args, pattern);
    S_vcat_mess(message, file, line, func, pattern, args);
    va_end(args);
    return message;
}

void
Err_warn_at(const char *file, int line, const char *func, 
             const char *pattern, ...)
{
    va_list args;
    CharBuf *message = CB_new(0);
    va_start(args, pattern);
    S_vcat_mess(message, file, line, func, pattern, args);
    va_end(args);
    Err_warn_mess(message);
}

void
kino_Err_throw_at(const char *file, int line, const char *func, 
                     const char *pattern, ...)
{
    va_list args;
    CharBuf *message = CB_new(0);
    va_start(args, pattern);
    S_vcat_mess(message, file, line, func, pattern, args);
    va_end(args);
    Err_throw_mess(message);
}

Obj*
kino_Err_assert_is_a(Obj *obj, VTable *vtable, const char *file, int line, 
                      const char *func)
{
    if (!obj) {
        Err_throw_at(file, line, func, "Object isn't a %o, it's NULL",
            VTable_Get_Name(vtable));
    }
    else if ( !Obj_Is_A(obj, vtable) ) {
        Err_throw_at(file, line, func, "Object isn't a %o, it's a %o",
            VTable_Get_Name(vtable), Obj_Get_Class_Name(obj));
    }
    return obj;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

