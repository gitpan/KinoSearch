use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch PACKAGE = KinoSearch::Util::I32Array

SV*
new(class_name, ...) 
    kino_ClassNameBuf class_name;
CODE:
{
    HV *const args_hash = XSBind_build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::I32Array::new_PARAMS");
    AV *ints_av = XSBind_maybe_extract_av(args_hash, SNL("ints"));
    kino_I32Array *self = NULL;
    kino_VTable *vtable 
        = kino_VTable_singleton((kino_CharBuf*)&class_name, NULL);

    if (ints_av) {
        chy_i32_t size  = av_len(ints_av) + 1;
        chy_i32_t *ints = KINO_MALLOCATE(size, chy_i32_t);
        chy_i32_t i;

        for (i = 0; i < size; i++) {
            SV **const sv_ptr = av_fetch(ints_av, i, 0);
            ints[i] = (sv_ptr && XSBind_sv_defined(*sv_ptr)) 
                    ? SvIV(*sv_ptr) 
                    : 0;
        }
        self = (kino_I32Array*)Kino_VTable_Make_Obj(vtable);
        kino_I32Arr_init(self, ints, size);
    }
    else {
        THROW(KINO_ERR, "Missing required param 'ints'");
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

__AUTO_XS__

{   "KinoSearch::Util::I32Array" => {
        bind_methods => [qw( Get Get_Size )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

