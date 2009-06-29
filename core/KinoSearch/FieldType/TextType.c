#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/FieldType/TextType.h"

ViewCharBuf*
TextType_make_blank(TextType *self)
{
    UNUSED_VAR(self);
    return ViewCB_new_from_trusted_utf8(NULL, 0);
}

i8_t
TextType_primitive_id(TextType *self)
{
    UNUSED_VAR(self);
    return FType_TEXT;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

