use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::SortCache" => {
        make_constructors => ["new"],
        bind_methods      => [qw( Ordinal Find )],
    }
}

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::SortCache

SV*
value(self, ...)
    kino_SortCache *self;
CODE:
{
    HV *const args_hash = XSBind_build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SortCache::value_PARAMS");
    chy_i32_t ord = XSBind_extract_iv(args_hash, SNL("ord"));
    kino_Obj *blank = Kino_SortCache_Make_Blank(self);
    kino_Obj *value = Kino_SortCache_Value(self, ord, blank);
    RETVAL = XSBind_kobj_to_pobj(value);
    KINO_DECREF(blank);
}
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

