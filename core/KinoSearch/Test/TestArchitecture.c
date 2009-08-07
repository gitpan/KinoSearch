#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestArchitecture.h"
#include "KinoSearch/Architecture.h"

TestArchitecture*
TestArch_new()
{
    TestArchitecture *self 
        = (TestArchitecture*)VTable_Make_Obj(TESTARCHITECTURE);
    return TestArch_init(self);
}

TestArchitecture*
TestArch_init(TestArchitecture *self)
{
    Arch_init((Architecture*)self);
    return self;
}

i32_t
TestArch_index_interval(TestArchitecture *self)
{
    UNUSED_VAR(self);
    return 5;
}

i32_t
TestArch_skip_interval(TestArchitecture *self)
{
    UNUSED_VAR(self);
    return 3;
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

