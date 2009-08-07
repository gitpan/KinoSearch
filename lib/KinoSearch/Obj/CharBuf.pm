use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Obj::CharBuf" => {
        bind_methods => [
            qw(
                Cat
                Cat_Char
                Grow
                Starts_With
                Ends_With
                Nip
                Chop
                Truncate
                Trim_Top
                Trim_Tail
                Trim
                SubString
                Code_Point_At
                Code_Point_From
                Set_Size
                Get_Size )
        ],
        make_getters => [qw( cap )]
    }
}

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Obj::CharBuf

chy_i32_t
cb_compare(cb_a, cb_b)
    kino_CharBuf *cb_a;
    kino_CharBuf *cb_b;
CODE: 
    RETVAL = kino_CB_compare(&cb_a, &cb_b);
OUTPUT: RETVAL

SV*
new(class_name, sv)
    kino_ClassNameBuf class_name;
    SV *sv;
CODE:
{
    STRLEN size;
    char *ptr = SvPVutf8(sv, size);
    kino_VTable *vtable 
        = kino_VTable_singleton((kino_CharBuf*)&class_name, NULL);
    kino_CharBuf *self = (kino_CharBuf*)Kino_VTable_Make_Obj(vtable);
    kino_CB_init(self, size);
    Kino_CB_Cat_Trusted_Str(self, ptr, size);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

SV*
_clone(self)
    kino_CharBuf *self;
CODE:
    KOBJ_TO_SV_NOINC( kino_CB_clone(self), RETVAL );
OUTPUT: RETVAL

SV*
_deserialize(either_sv, instream)
    SV *either_sv;
    kino_InStream *instream;
CODE:
    CHY_UNUSED_VAR(either_sv);
    KOBJ_TO_SV_NOINC( kino_CB_deserialize(NULL, instream), RETVAL );
OUTPUT: RETVAL

SV*
to_perl(self)
    kino_CharBuf *self;
CODE:
    RETVAL = newSVpv(self->ptr, self->size);
    SvUTF8_on(RETVAL);
OUTPUT: RETVAL

MODULE = KinoSearch     PACKAGE = KinoSearch::Obj::ViewCharBuf

SV*
_new(class_name, sv)
    kino_ClassNameBuf class_name;
    SV *sv;
CODE:
{
    STRLEN size;
    char *ptr = SvPVutf8(sv, size);
    kino_ViewCharBuf *self 
        = kino_ViewCB_new_from_trusted_utf8(ptr, size);
    CHY_UNUSED_VAR(class_name);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
