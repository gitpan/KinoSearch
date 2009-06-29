use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::OutStream

SV*
new(class_name, file_des)
    kino_ClassNameBuf class_name;
    kino_FileDes *file_des;
CODE:
{
    kino_VTable *vtable 
        = kino_VTable_singleton((kino_CharBuf*)&class_name, NULL);
    kino_OutStream *self = (kino_OutStream*)Kino_VTable_Make_Obj(vtable);
    kino_OutStream_init(self, file_des);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

void
print(self, ...)
    kino_OutStream *self;
PPCODE:
{
    int i;
    for (i = 1; i < items; i++) {
        STRLEN len;
        char *ptr = SvPV( ST(i), len);
        Kino_OutStream_Write_Bytes(self, ptr, len);
    }
}

void 
write_string(self, aSV)
    kino_OutStream *self;
    SV *aSV;
PPCODE:
{
    STRLEN len = 0;
    char *ptr = SvPVutf8(aSV, len);
    Kino_OutStream_Write_C32(self, len);
    Kino_OutStream_Write_Bytes(self, ptr, len);
}

void
write_bytes(self, aSV)
    kino_OutStream *self;
    SV *aSV;
PPCODE:
{
    STRLEN len;
    char *ptr = SvPV(aSV, len);
    Kino_OutStream_Write_Bytes(self, ptr, len);
}

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';    # Don't use this yet.
    my $outstream = $folder->open_out($filename) 
        or die "Can't open $filename";
    $outstream->write_u64($file_position);
END_SYNOPSIS

{   "KinoSearch::Store::OutStream" => {
        bind_methods => [
            qw(
                Tell
                Length
                Flush
                Close
                Absorb
                Write_I8
                Write_I32
                Write_I64
                Write_U8
                Write_U32
                Write_U64
                Write_C32
                Write_C64
                Write_F32
                Write_F64
                )
        ],
        make_getters => [qw( file_des )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

