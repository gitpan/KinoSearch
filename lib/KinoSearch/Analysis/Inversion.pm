use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Analysis::Inversion

SV*
new(...)
CODE:
{
    kino_Token *starter_token = NULL;
    /* parse params, only if there's more than one arg */
    if (items > 1) {
        HV *const args_hash = XSBind_build_args_hash( &(ST(0)), 1, items,
            "KinoSearch::Analysis::Inversion::new_PARAMS");
        SV *text_sv = XSBind_extract_sv(args_hash, SNL("text"));
        STRLEN len;
        char *text = SvPVutf8(text_sv, len);
        starter_token = kino_Token_new(text, len, 0, len, 1.0, 1);
    }
        
    KOBJ_TO_SV_NOINC( kino_Inversion_new(starter_token), RETVAL );
    KINO_DECREF(starter_token);
}
OUTPUT: RETVAL

__AUTO_XS__

{   "KinoSearch::Analysis::Inversion" => {
        bind_methods => [qw( Append Reset Invert Next )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

