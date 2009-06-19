use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Analysis::Token

SV*
new(class_name, ...)
    kino_ClassNameBuf class_name;
CODE:
{
    kino_VTable *vtable 
        = kino_VTable_singleton((kino_CharBuf*)&class_name, NULL);
    STRLEN len;
    HV *const args_hash    = XSBind_build_args_hash( &(ST(0)), 1, items,
            "KinoSearch::Analysis::Token::new_PARAMS");
    SV *text_sv         = XSBind_extract_sv(args_hash, SNL("text"));
    char *text          = SvPV(text_sv, len);
    chy_u32_t start_off = XSBind_extract_uv(args_hash, SNL("start_offset"));
    chy_u32_t end_off   = XSBind_extract_uv(args_hash, SNL("end_offset"));
    chy_i32_t pos_inc   = XSBind_extract_iv(args_hash, SNL("pos_inc"));
    float boost         = (float)XSBind_extract_nv(args_hash, SNL("boost"));
    kino_Token *self    = (kino_Token*)Kino_VTable_Make_Obj(vtable);
    kino_Token_init(self, text, len, start_off, end_off, boost, 
        pos_inc);
    KOBJ_TO_SV_NOINC(self, RETVAL);
}
OUTPUT: RETVAL

void
_set_or_get2(self, ...)
    kino_Token *self;
ALIAS:
    set_text         = 1
    get_text         = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  free(self->text);
             {
                 STRLEN len;
                 char *str = SvPVutf8( ST(1), len);
                 self->text = kino_StrHelp_strndup(str, len);
                 self->len = len;
             }

    case 2:  retval = newSVpvn(self->text, self->len);
             SvUTF8_on(retval);
             break;

    END_SET_OR_GET_SWITCH
}

__AUTO_XS__

{   "KinoSearch::Analysis::Token" => {
        make_getters      => [qw( start_offset end_offset boost pos_inc )],
    }
}

__POD__

=head1 NAME

KinoSearch::Analysis::Token - Redacted.

=head1 REDACTED

Token's public API has been redacted.

=head1 COPYRIGHT

Copyright 2005-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut

