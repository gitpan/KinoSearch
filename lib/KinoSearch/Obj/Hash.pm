use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
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
    kino_ZombieCharBuf key;
CODE:
    KOBJ_TO_SV( kino_Hash_fetch(self, (kino_Obj*)&key), RETVAL );
OUTPUT: RETVAL

void
store(self, key, value);
    kino_Hash          *self; 
    kino_ZombieCharBuf  key;
    kino_Obj           *value;
PPCODE:
{
    if (value) { KINO_INCREF(value); }
    kino_Hash_store(self, (kino_Obj*)&key, value);
}

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
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj::Hash",
    xs_code      => $xs_code,
    bind_methods => [
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
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

