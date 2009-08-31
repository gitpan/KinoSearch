use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch PACKAGE = KinoSearch::Util::I32Array

SV*
new(either_sv, ...) 
    SV *either_sv;
CODE:
{
    SV *ints_sv = NULL;
    AV *ints_av = NULL;
    kino_I32Array *self = NULL;

    XSBind_allot_params( &(ST(0)), 1, items, 
        "KinoSearch::Util::I32Array::new_PARAMS",
        &ints_sv, SNL("ints"),
        NULL);
    if (XSBind_sv_defined(ints_sv) && SvROK(ints_sv)) {
        ints_av = (AV*)SvRV(ints_sv);
    }

    if (ints_av && SvTYPE(ints_av) == SVt_PVAV) {
        chy_i32_t size  = av_len(ints_av) + 1;
        chy_i32_t *ints = KINO_MALLOCATE(size, chy_i32_t);
        chy_i32_t i;

        for (i = 0; i < size; i++) {
            SV **const sv_ptr = av_fetch(ints_av, i, 0);
            ints[i] = (sv_ptr && XSBind_sv_defined(*sv_ptr)) 
                    ? SvIV(*sv_ptr) 
                    : 0;
        }
        self = (kino_I32Array*)XSBind_new_blank_obj(either_sv);
        kino_I32Arr_init(self, ints, size);
    }
    else {
        THROW(KINO_ERR, "Required param 'ints' isn't an arrayref");
    }
    
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

SV*
to_arrayref(self)
    kino_I32Array *self;
CODE:
{
    AV *out_av = newAV();
    chy_u32_t i;
    chy_u32_t size = Kino_I32Arr_Get_Size(self);

    av_extend(out_av, size);
    for (i = 0; i < size; i++) {
        chy_i32_t result = Kino_I32Arr_Get(self, i);
        SV* result_sv = result == -1 ? newSV(0) : newSViv(result);
        av_push(out_av, result_sv);
    }
    RETVAL = newRV_noinc((SV*)out_av);
}
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Util::I32Array",
    xs_code      => $xs_code,
    bind_methods => [qw( Get Get_Size )],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

