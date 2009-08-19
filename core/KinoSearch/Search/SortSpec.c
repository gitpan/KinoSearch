#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/SortSpec.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/IndexReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/SortRule.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/I32Array.h"
#include "KinoSearch/Util/SortUtils.h"

SortSpec*
SortSpec_new(VArray *rules)
{
    SortSpec *self = (SortSpec*)VTable_Make_Obj(SORTSPEC);
    return SortSpec_init(self, rules);
}

SortSpec*
SortSpec_init(SortSpec *self, VArray *rules)
{
    i32_t i, max;
    self->rules = VA_Shallow_Copy(rules);
    for (i = 0, max = VA_Get_Size(rules); i < max; i++) {
        SortRule *rule = (SortRule*)VA_Fetch(rules, i);
        ASSERT_IS_A(rule, SORTRULE);
    }
    return self;
}

void
SortSpec_destroy(SortSpec *self)
{
    DECREF(self->rules);
    SUPER_DESTROY(self, SORTSPEC);
}

SortSpec*
SortSpec_deserialize(SortSpec *self, InStream *instream)
{
    u32_t num_rules = InStream_Read_C32(instream);
    VArray *rules = VA_new(num_rules);
    u32_t i;

    /* Create base object. */
    self = self ? self : (SortSpec*)VTable_Make_Obj(SORTSPEC);

    /* Add rules. */
    for (i = 0; i < num_rules; i++) {
        VA_Push(rules, (Obj*)SortRule_deserialize(NULL, instream));
    }
    SortSpec_init(self, rules);
    DECREF(rules);

    return self;
}

VArray*
SortSpec_get_rules(SortSpec *self) { return self->rules; }

void
SortSpec_serialize(SortSpec *self, OutStream *target)
{
    u32_t num_rules = VA_Get_Size(self->rules);
    u32_t i;
    OutStream_Write_C32(target, num_rules);
    for (i = 0; i < num_rules; i++) {
        SortRule *rule = (SortRule*)VA_Fetch(self->rules, i);
        SortRule_Serialize(rule, target);
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

