use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::SortExRun

int
compare(self, obj_a, obj_b)
    kino_SortExRun *self;
    kino_Obj       *obj_a;
    kino_Obj       *obj_b;
CODE:
    ABSTRACT_METHOD_CHECK(self, SortExRun, Compare, compare);
    RETVAL = Kino_SortExRun_Compare(self, &obj_a, &obj_b);
OUTPUT: RETVAL

SV*
pop_slice(self, endpost)
    kino_SortExRun *self;
    kino_Obj       *endpost;
CODE:
{
    AV *out_av = newAV();
    chy_u32_t slice_size;
    kino_Obj **elems = Kino_SortExRun_Pop_Slice(self, endpost, &slice_size);
    while (slice_size--) {
        SV *sv = Kino_Obj_To_Host(elems[slice_size]);
        av_store(out_av, slice_size, sv);
        KINO_DECREF(elems[slice_size]);
    }
    RETVAL = newRV_noinc( (SV*)out_av );
}
OUTPUT: RETVAL

chy_u32_t
cache_count(self)
    kino_SortExRun *self;
CODE:
    RETVAL = KINO_SORTEXRUN_CACHE_COUNT(self);
OUTPUT: RETVAL

__AUTO_XS__

{   "KinoSearch::Util::SortExRun" => {
        bind_methods => [ qw( Refill Peek_Last Read_Elem ) ],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

