use KinoSearch;

1;

__END__

__XS__

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
        if (!sv_isobject(elem_sv)) THROW(KINO_ERR, "Not a %o.", KINO_OBJ->name);
        elem = XSBind_sv_to_kobj(elem_sv, KINO_OBJ);
        Kino_SortEx_Feed(self, elem, size);
    }
    else {
        STRLEN len;
        char *ptr = SvPV(elem_sv, len);
        kino_ByteBuf *bb = kino_BB_new_bytes(ptr, len);
        if (items < 3) size = len + sizeof(kino_ByteBuf);
        Kino_SortEx_Feed(self, (kino_Obj*)bb, size);
        KINO_DECREF(bb);
    }
}

IV
_DEFAULT_MEM_THRESHOLD()
CODE:
    RETVAL = KINO_SORTEX_DEFAULT_MEM_THRESHOLD;
OUTPUT: RETVAL

SV*
_peek_cache(self)
    kino_SortExternal *self;
CODE:
{
    AV *out_av = newAV();
    chy_u32_t i;
    for (i = self->cache_tick; i < self->cache_max; i++) {
        SV *elem_sv = XSBind_kobj_to_pobj(self->cache[i]);
        av_push(out_av, elem_sv);
    }
    RETVAL = newRV_noinc((SV*)out_av);
}
OUTPUT: RETVAL

chy_u32_t
cache_count(self)
    kino_SortExternal *self;
CODE:
    RETVAL = KINO_SORTEX_CACHE_COUNT(self);
OUTPUT: RETVAL

void
_set_or_get2(self, ...)
    kino_SortExternal *self;
ALIAS:
    get_runs = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  {
                chy_u32_t i;
                kino_VArray *runs = kino_VA_new(self->num_runs);
                for (i = 0; i < self->num_runs; i++) {
                    Kino_VA_Push(runs, KINO_INCREF(self->runs[i]));
                }
                retval = Kino_Obj_To_Host(runs);
                KINO_DECREF(runs);
             }
             break;
    
    END_SET_OR_GET_SWITCH
}

__AUTO_XS__

{   "KinoSearch::Util::SortExternal" => {
        bind_methods =>
            [ qw( Fetch Flush Flip Add_Run Peek Sort_Cache Clear_Cache ) ],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

