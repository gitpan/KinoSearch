use KinoSearch;

1;

__END__

__BINDING__

my $float32_xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Obj::Float32

SV*
new(either_sv, value)
    SV    *either_sv;
    float  value;
CODE:
{
    kino_Float32 *self = (kino_Float32*)XSBind_new_blank_obj(either_sv);
    kino_Float32_init(self, value);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL
END_XS_CODE

my $float64_xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Obj::Float64

SV*
new(either_sv, value)
    SV     *either_sv;
    double  value;
CODE:
{
    kino_Float64 *self = (kino_Float64*)XSBind_new_blank_obj(either_sv);
    kino_Float64_init(self, value);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj::Float32",
    xs_code      => $float32_xs_code,
    bind_methods => [qw( Set_Value Get_Value )],
);
Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj::Float64",
    xs_code      => $float64_xs_code,
    bind_methods => [qw( Set_Value Get_Value )],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

