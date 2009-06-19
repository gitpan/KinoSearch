use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::IndexFileNames

IV
extract_gen(name)
    kino_CharBuf name;
CODE:
    RETVAL = kino_IxFileNames_extract_gen(&name);
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

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

