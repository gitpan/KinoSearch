use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::Host

=for comment

These are all for testing purposes only.

=cut

IV
_test(...)
CODE:
    RETVAL = items;
OUTPUT: RETVAL

SV*
_test_obj(...)
CODE:
{
    kino_ByteBuf *test_obj = kino_BB_new_bytes("blah", 4);
    SV *pack_var = get_sv("KinoSearch::Util::Host::testobj", 1);
    RETVAL = Kino_Obj_To_Host(test_obj);
    SvSetSV_nosteal(pack_var, RETVAL);
    KINO_DECREF(test_obj);
    CHY_UNUSED_VAR(items);
}
OUTPUT: RETVAL

void
_callback(obj)
    kino_Obj *obj;
PPCODE:
{
    kino_CharBuf blank = KINO_ZCB_BLANK; 
    kino_Host_callback(obj, "_test", 2, KINO_ARG_OBJ("nothing", &blank),
        KINO_ARG_I32("foo", 3));
}

IV
_callback_i(obj)
    kino_Obj *obj;
CODE:
{
    kino_CharBuf blank = KINO_ZCB_BLANK;
    RETVAL = kino_Host_callback_i(obj, "_test", 2, 
        KINO_ARG_OBJ("nothing", &blank), KINO_ARG_I32("foo", 3));
}
OUTPUT: RETVAL

float
_callback_f(obj)
    kino_Obj *obj;
CODE:
{
    kino_CharBuf blank = KINO_ZCB_BLANK;
    RETVAL = kino_Host_callback_f(obj, "_test", 2, 
        KINO_ARG_OBJ("nothing", &blank), KINO_ARG_I32("foo", 3));
}
OUTPUT: RETVAL

SV*
_callback_obj(obj)
    kino_Obj *obj;
CODE: 
{
    kino_Obj *other = kino_Host_callback_obj(obj, "_test_obj", 0);
    RETVAL = Kino_Obj_To_Host(other);
    KINO_DECREF(other);
}
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

