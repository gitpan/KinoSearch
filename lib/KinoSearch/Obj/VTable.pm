use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Obj::VTable" => {
        bind_methods => [qw( Get_Name )],
        make_getters => [qw( parent )],
    }
}

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Obj::VTable

SV*
_get_registry()
CODE:
    if (kino_VTable_registry == NULL)
        kino_VTable_init_registry();
    RETVAL = Kino_Obj_To_Host(kino_VTable_registry);
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2007-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

