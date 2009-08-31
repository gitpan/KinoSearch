use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Obj::VTable

SV*
_get_registry()
CODE:
    if (kino_VTable_registry == NULL)
        kino_VTable_init_registry();
    RETVAL = Kino_Obj_To_Host(kino_VTable_registry);
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj::VTable",
    xs_code      => $xs_code,
    bind_methods => [qw( Get_Name Get_Parent )],
);

__COPYRIGHT__

Copyright 2007-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

