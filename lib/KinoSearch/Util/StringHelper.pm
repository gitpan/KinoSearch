package KinoSearch::Util::StringHelper;
use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Util::StringHelper

=for comment 

Turn an SV's UTF8 flag on.  Equivalent to Encode::_utf8_on, but we don't have
to load Encode.

=cut

void
utf8_flag_on(sv)
    SV *sv;
PPCODE:
    SvUTF8_on(sv);

=for comment

Turn an SV's UTF8 flag off.

=cut

void
utf8_flag_off(sv)
    SV *sv;
PPCODE:
    SvUTF8_off(sv);

SV*
to_base36(num)
    uint64_t num;
CODE:
{
    char base36[kino_StrHelp_MAX_BASE36_BYTES];
    size_t size = kino_StrHelp_to_base36(num, &base36);
    RETVAL = newSVpvn(base36, size);
}
OUTPUT: RETVAL

IV
from_base36(str)
    char *str;
CODE:
    RETVAL = strtol(str, NULL, 36);
OUTPUT: RETVAL

=for comment

Upgrade a SV to UTF8, converting Latin1 if necessary. Equivalent to
utf::upgrade().

=cut

void
utf8ify(sv)
    SV *sv;
PPCODE:
    sv_utf8_upgrade(sv);

chy_bool_t
utf8_valid(sv)
    SV *sv;
CODE:
{
    STRLEN len;
    char *ptr = SvPV(sv, len);
    RETVAL = kino_StrHelp_utf8_valid(ptr, len);
}
OUTPUT: RETVAL

=for comment

Concatenate one scalar onto the end of the other, ignoring UTF-8 status of the
second scalar.  This is necessary because $not_utf8 . $utf8 results in a
scalar which has been infected by the UTF-8 flag of the second argument.

=cut

void
cat_bytes(sv, catted)
    SV *sv;
    SV *catted;
PPCODE:
{
    STRLEN len;
    char *ptr = SvPV(catted, len);
    if (SvUTF8(sv)) { KINO_THROW(KINO_ERR, "Can't cat_bytes onto a UTF-8 SV"); }
    sv_catpvn(sv, ptr, len);
}
END_XS_CODE

Clownfish::Binding::Perl::Class->register(
    parcel     => "KinoSearch",
    class_name => "KinoSearch::Util::StringHelper",
    xs_code    => $xs_code,
);

__COPYRIGHT__

Copyright 2005-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

