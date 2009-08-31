#ifndef H_KINO_TOOLSET
#define H_KINO_TOOLSET 1

/* ToolSet groups together several commonly used header files, so that only
 * one pound-include directive is needed for them.
 *
 * It should only be used internally, and only included in C files rather than
 * header files, so that the header files remain as sparse as possible.
 */

#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#define C_KINO_ZOMBIECHARBUF

#include "charmony.h"
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "KinoSearch/Obj.h"
#include "KinoSearch/Obj/BitVector.h"
#include "KinoSearch/Obj/ByteBuf.h"
#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Obj/Hash.h"
#include "KinoSearch/Obj/Num.h"
#include "KinoSearch/Obj/Undefined.h"
#include "KinoSearch/Obj/VArray.h"
#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Util/NumberUtils.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/StringHelper.h"

#endif /* H_KINO_TOOLSET */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

