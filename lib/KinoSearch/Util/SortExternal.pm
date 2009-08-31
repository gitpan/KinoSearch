use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch    PACKAGE = KinoSearch::Util::SortExternal

void
feed(self, elem_sv, ...)
    kino_SortExternal *self;
    SV *elem_sv;
PPCODE:
{
    chy_u32_t size = items == 3 ? SvUV( ST(2) ) : 0;

    if (sv_derived_from(elem_sv, "KinoSearch::Obj")) {
        kino_Obj *elem;
        if (items < 3) THROW(KINO_ERR, "Must supply size along with object");
        if (!sv_isobject(elem_sv)) {
            THROW(KINO_ERR, "Not a %o", Kino_VTable_Get_Name(KINO_OBJ));
        }
        elem = XSBind_sv_to_kobj(elem_sv, KINO_OBJ);
        Kino_SortEx_Feed(self, elem, size);
    }
    else {
        STRLEN len;
        char *ptr = SvPV(elem_sv, len);
        kino_ByteBuf *bb = kino_BB_new_bytes(ptr, len);
        if (items < 3) size = len + 20; /* 20 = approx. sizeof(ByteBuf) */
        Kino_SortEx_Feed(self, (kino_Obj*)bb, size);
        KINO_DECREF(bb);
    }
}

IV
_DEFAULT_MEM_THRESHOLD()
CODE:
    RETVAL = KINO_SORTEX_DEFAULT_MEM_THRESHOLD;
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Util::SortExternal",
    xs_code      => $xs_code,
    bind_methods => [
        qw(
            Fetch
            Flush
            Flip
            Add_Run
            Peek
            Sort_Cache
            Clear_Cache
            Cache_Count
            Get_Num_Runs
            )
    ],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

