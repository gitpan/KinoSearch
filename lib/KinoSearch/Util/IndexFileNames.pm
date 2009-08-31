use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Util::IndexFileNames

IV
extract_gen(name)
    kino_ZombieCharBuf name;
CODE:
    RETVAL = kino_IxFileNames_extract_gen((kino_CharBuf*)&name);
OUTPUT: RETVAL

SV*
latest_snapshot(folder)
    kino_Folder *folder;
CODE:
{
    kino_CharBuf *latest = kino_IxFileNames_latest_snapshot(folder);
    RETVAL = XSBind_cb_to_sv(latest);   
    KINO_DECREF(latest);
}
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel     => "KinoSearch",
    class_name => "KinoSearch::Util::IndexFileNames",
    xs_code    => $xs_code,
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

