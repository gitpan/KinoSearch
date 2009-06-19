use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::ByteBuf

SV*
new(class_name, sv)
    kino_ClassNameBuf class_name;
    SV *sv;
CODE:
{
    STRLEN size;
    char *ptr = SvPV(sv, size);
    kino_VTable *vtable 
        = kino_VTable_singleton((kino_CharBuf*)&class_name, NULL);
    kino_ByteBuf *self = (kino_ByteBuf*)Kino_VTable_Make_Obj(vtable);
    kino_BB_init(self, size);
    Kino_BB_Copy_Str(self, ptr, size);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

SV*
_deserialize(either_sv, instream)
    SV *either_sv;
    kino_InStream *instream;
CODE:
    CHY_UNUSED_VAR(either_sv);
    KOBJ_TO_SV_NOINC(kino_BB_deserialize(NULL, instream), RETVAL);
OUTPUT: RETVAL

chy_i32_t
bb_compare(bb_a, bb_b)
    kino_ByteBuf *bb_a;
    kino_ByteBuf *bb_b;
CODE: 
    RETVAL = kino_BB_compare(&bb_a, &bb_b);
OUTPUT: RETVAL

__AUTO_XS__

{   "KinoSearch::Util::ByteBuf" => {
        bind_methods => [
            qw( Get_Size
                Get_Capacity
                Copy
                Cat
                Grow
                )
        ],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

