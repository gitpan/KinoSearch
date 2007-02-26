#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERM_VTABLE
#include "KinoSearch/Index/Term.r"

Term*
Term_new(const ByteBuf *field, const ByteBuf *text) 
{
    CREATE(self, Term, TERM);

    /* assign */
    self->field = BB_CLONE(field);
    self->text  = BB_CLONE(text);

    return self;
}

Term*
Term_new_str(const char *field, const char *text) 
{
    CREATE(self, Term, TERM);

    /* assign */
    self->field = BB_new_str(field, strlen(field));
    self->text  = BB_new_str(text,  strlen(text));

    return self;
}

void
Term_serialize(Term *self, ByteBuf *target)
{
    BB_Serialize(self->field, target);
    BB_Serialize(self->text, target);
}

Term*
Term_deserialize(ViewByteBuf *serialized)
{
    CREATE(self, Term, TERM);

    self->field = BB_deserialize(serialized);
    self->text  = BB_deserialize(serialized);

    return self;
}

ByteBuf*
Term_get_field(Term *self)
{
    return self->field;
}

ByteBuf*
Term_get_text(Term *self)
{
    return self->text;
}

void
Term_copy(Term *self, Term *other)
{
    BB_Copy_BB(self->field, other->field);
    BB_Copy_BB(self->text,  other->text);
}

kino_Term*
Term_clone(Term *self)
{
    return Term_new(self->field, self->text);
}

ByteBuf*
Term_to_string(Term *self)
{
    ByteBuf *const field = self->field;
    ByteBuf *const text  = self->text;
    ByteBuf *retval = BB_new(field->len + text->len + 1);
    char *ptr = retval->ptr;

    memcpy(ptr, field->ptr, field->len);
    ptr += field->len;
    *ptr++ = ':';
    memcpy(ptr, text->ptr, text->len);
    ptr += text->len;
    *ptr++ = '\0';

    return retval;
}

bool_t
Term_equals(Term *self, Term *other)
{
    if (   BB_Equals(self->field, (Obj*)other->field)
        && BB_Equals(self->text, (Obj*)other->text)
    ) {
        return true;
    }
    else {
        return false;
    }
}

void
Term_destroy(Term *self)
{
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->text);
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

