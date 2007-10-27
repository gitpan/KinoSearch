/* Charmonizer/Probe/VariadicMacros.h
 */

#ifndef H_CHAZ_VARIADIC_MACROS
#define H_CHAZ_VARIADIC_MACROS 

#include <stdio.h>

/* Run the VariadicMacros module.
 *
 * If your compiler supports ISO-style variadic macros, this will be defined:
 * 
 * HAS_ISO_VARIADIC_MACROS
 * 
 * If your compiler supports GNU-style variadic macros, this will be defined:
 * 
 * HAS_GNUC_VARIADIC_MACROS
 * 
 * If you have at least one of the above, this will be defined:
 * 
 * HAS_VARIADIC_MACROS
 */
void chaz_VariadicMacros_run(void);

#ifdef CHAZ_USE_SHORT_NAMES
  #define VariadicMacros_run    chaz_VaradicMacros_run
#endif

#endif /* H_CHAZ_VARIADIC_MACROS */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

