use KinoSearch;

1;

__END__

__XS__

MODULE =  KinoSearch    PACKAGE = KinoSearch::Obj::Hash

SV*
_deserialize(either_sv, instream)
    SV *either_sv;
    kino_InStream *instream;
CODE:
    CHY_UNUSED_VAR(either_sv);
    KOBJ_TO_SV_NOINC(kino_Hash_deserialize(NULL, instream), RETVAL);
OUTPUT: RETVAL

SV*
_fetch(self, key)
    kino_Hash *self;
    kino_CharBuf key;
CODE:
    KOBJ_TO_SV( Kino_Hash_Fetch(self, (kino_Obj*)&key), RETVAL );
OUTPUT: RETVAL

void
iter_next(self)
    kino_Hash *self;
PPCODE:
{
    kino_Obj *key;
    kino_Obj *val;

    if (Kino_Hash_Iter_Next(self, &key, &val)) {
        SV *key_sv = Kino_Obj_To_Host(key);
        SV *val_sv = Kino_Obj_To_Host(val);

        XPUSHs(sv_2mortal( key_sv ));
        XPUSHs(sv_2mortal( val_sv ));
        XSRETURN(2);
    }
    else {
        XSRETURN_EMPTY;
    }
}

__AUTO_XS__

{   "KinoSearch::Obj::Hash" => {
        bind_positional => [qw( Store )],
        bind_methods    => [
            qw(
                Fetch
                Delete
                Keys
                Values
                Find_Key
                Clear
                Iter_Init
                Get_Size
                )
        ],
        make_constructors => ["new"],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

