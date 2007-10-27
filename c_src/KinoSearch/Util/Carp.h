/* KinoSearch/Util/Carp.h - stack traces from C
 *
 * This module makes it possible to invoke Carp::confess() from C.  Modules
 * that use it will need to "use Carp;" -- which is usually taken care of by
 * "use KinoSearch::Util::ToolSet;".
 */

#ifndef H_KINO_CARP
#define H_KINO_CARP 1

/* Print an error message to stderr with some C contextual information.
 * Usually invoked via the Warn(pat, ...) macro.
 */
void
kino_Carp_warn_at(const char *file, int line, const char *func, 
                  const char *pat, ...);

/* Die with a Perl stack trace and C contextual information. Usually invoked
 * via the CONFESS(pat, ...) macro.
 */
void
kino_Carp_confess_at(const char *file, int line, const char *func, 
                     const char *pat, ...);

#ifdef CHY_HAS_FUNC_MACRO
 #define KINO_CARP_FUNC_MACRO CHY_FUNC_MACRO
#else
 #define KINO_CARP_FUNC_MACRO NULL
#endif

/* Macro version of kino_Carp_confess_at which inserts contextual information
 * automatically, provided that the compiler supports the necessary features.
 */
#ifdef CHY_HAS_VARIADIC_MACROS
 #ifdef CHY_HAS_ISO_VARIADIC_MACROS
  #define KINO_CONFESS(...) \
    kino_Carp_confess_at(__FILE__, __LINE__, KINO_CARP_FUNC_MACRO, \
        __VA_ARGS__)
  #define Kino_Carp_Warn(...) \
    kino_Carp_warn_at(__FILE__, __LINE__, KINO_CARP_FUNC_MACRO, __VA_ARGS__)
 #elif defined(CHY_HAS_GNUC_VARIADIC_MACROS)
  #define KINO_CONFESS(args...) \
    kino_Carp_confess_at(__FILE__, __LINE__, KINO_CARP_FUNC_MACRO, ##args)
  #define Kino_Carp_Warn(args...) \
    kino_Carp_warn_at(__FILE__, __LINE__, KINO_CARP_FUNC_MACRO, ##args)
 #endif
#else
void 
KINO_CONFESS(char* format, ...);
void 
Kino_Carp_Warn(char* format, ...);

#endif

#define KINO_ABSTRACT_DEATH(self, method) \
    KINO_CONFESS("Abstract method " method " not defined by %s", \
        self->_->class_name);

/* Store a message in kino_Carp_kerror.  
 */

void
kino_Carp_set_kerror(const char *pat, ...);

extern char *kino_Carp_kerror;

#ifdef KINO_USE_SHORT_NAMES
  #define Carp_confess_at   kino_Carp_confess_at
  #define Carp_warn_at      kino_Carp_warn_at
  #define CONFESS           KINO_CONFESS
  #define ABSTRACT_DEATH    KINO_ABSTRACT_DEATH  
  #define Warn              Kino_Carp_Warn
  #define Carp_set_kerror   kino_Carp_set_kerror
  #define Carp_kerror       kino_Carp_kerror
#endif

#endif /* H_KINO_CARP */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

