use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Index::SortCache

SV*
value(self, ...)
    kino_SortCache *self;
CODE:
{
    SV *ord_sv = NULL;
    chy_i32_t ord = 0;

    XSBind_allot_params( &(ST(0)), 1, items, 
        "KinoSearch::Index::SortCache::value_PARAMS",
        &ord_sv, SNL("ord"), 
        NULL);
    if (ord_sv) { ord = SvIV(ord_sv); }
    else { THROW(KINO_ERR, "Missing required param 'ord'"); }

    {
        kino_Obj *blank = Kino_SortCache_Make_Blank(self);
        kino_Obj *value = Kino_SortCache_Value(self, ord, blank);
        RETVAL = XSBind_kobj_to_pobj(value);
        KINO_DECREF(blank);
    }
}
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::SortCache",
    xs_code           => $xs_code,
    bind_constructors => ["new"],
    bind_methods      => [qw( Ordinal Find )],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

