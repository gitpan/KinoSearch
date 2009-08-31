use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch     PACKAGE = KinoSearch::Obj::CharBuf

chy_i32_t
cb_compare(cb_a, cb_b)
    kino_CharBuf *cb_a;
    kino_CharBuf *cb_b;
CODE: 
    RETVAL = kino_CB_compare(&cb_a, &cb_b);
OUTPUT: RETVAL

SV*
new(either_sv, sv)
    SV *either_sv;
    SV *sv;
CODE:
{
    STRLEN size;
    char *ptr = SvPVutf8(sv, size);
    kino_CharBuf *self = (kino_CharBuf*)XSBind_new_blank_obj(either_sv);
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
    RETVAL = XSBind_cb_to_sv(self);
OUTPUT: RETVAL

MODULE = KinoSearch     PACKAGE = KinoSearch::Obj::ViewCharBuf

SV*
_new(unused, sv)
    SV *unused;
    SV *sv;
CODE:
{
    STRLEN size;
    char *ptr = SvPVutf8(sv, size);
    kino_ViewCharBuf *self 
        = kino_ViewCB_new_from_trusted_utf8(ptr, size);
    CHY_UNUSED_VAR(unused);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj::CharBuf",
    xs_code      => $xs_code,
    bind_methods => [
        qw(
            Cat
            Cat_Char
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
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
