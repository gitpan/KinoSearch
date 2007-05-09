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

#include "charmony.h"
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MathUtils.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/StringHelper.h"
#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/VirtualTable.r"
#include "KinoSearch/Util/DynVirtualTable.r"
#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/ViewByteBuf.r"
#include "KinoSearch/Util/VArray.r"
#include "KinoSearch/Util/Hash.r"

#endif /* H_KINO_TOOLSET */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

