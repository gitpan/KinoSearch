use strict;
use warnings;

package KinoSearch::Index::SegLexicon;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::Lexicon );

our %instance_vars = (
    # constructor params
    schema    => undef,
    folder    => undef,
    seg_info  => undef,
    is_index  => 0,
    lex_cache => undef,
    field     => undef,
);

use KinoSearch::Index::Term;
use KinoSearch::Index::TermInfo;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::SegLexicon 

kino_SegLexicon*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SegLexicon::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");
    chy_bool_t is_index = extract_iv(args_hash, SNL("is_index"));
    SV *lex_cache_sv = extract_sv(args_hash, SNL("lex_cache"));
    kino_SegLexCache *lex_cache = NULL;
    SV *field_sv = extract_sv(args_hash, SNL("field"));
    kino_ByteBuf field = KINO_BYTEBUF_BLANK;

    MAYBE_EXTRACT_STRUCT(lex_cache_sv, lex_cache, kino_SegLexCache*, 
        "KinoSearch::Index::SegLexCache");

    if (SvOK(field_sv))
        SV_TO_TEMP_BB(field_sv, field);
    else 
        CONFESS("Missing required param 'field'");

    RETVAL = kino_SegLex_new(schema, folder, seg_info, &field, 
        lex_cache, is_index);
}
OUTPUT: RETVAL

chy_i32_t
get_field_num(self);
    kino_SegLexicon *self;
CODE:
    RETVAL = Kino_SegLex_Get_Field_Num(self);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_SegLexicon *self;
ALIAS:
    get_term_info            = 4
    is_index                 = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 4:  retval = kobj_to_pobj(Kino_SegLex_Get_Term_Info(self));
             break;

    case 10: retval = newSViv(self->is_index);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegLexicon - Single-segment Lexicon.

=head1 DESCRIPTION

Single-segment implementation of KinoSearch::Index::Lexicon.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
