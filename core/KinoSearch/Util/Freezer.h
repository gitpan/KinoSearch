#ifndef H_KINO_FREEZER
#define H_KINO_FREEZER 1

#include "KinoSearch/Obj.h"

/* Store an arbitrary object to the outstream.
 */
void
kino_Freezer_freeze(kino_Obj *obj, kino_OutStream *outstream);

/* Retrieve an arbitrary object from the instream.
 */
kino_Obj*
kino_Freezer_thaw(kino_InStream *instream);

#define KINO_FREEZE(_obj, _outstream) \
    kino_Freezer_freeze((Obj*)(_obj), (outstream))

#define KINO_THAW(_instream) \
    kino_Freezer_thaw(instream)

#ifdef KINO_USE_SHORT_NAMES
  #define Freezer_freeze        kino_Freezer_freeze
  #define Freezer_thaw          kino_Freezer_thaw
  #define FREEZE                KINO_FREEZE 
  #define THAW                  KINO_THAW
#endif

#endif /* H_KINO_FREEZER */

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

