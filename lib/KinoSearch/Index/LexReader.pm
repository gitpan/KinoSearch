use strict;
use warnings;

package KinoSearch::Index::LexReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    schema   => undef,
    folder   => undef,
    seg_info => undef,
);

use KinoSearch::Index::Term;
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::SegLexicon;
use KinoSearch::Index::LexCache;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::LexReader 

kino_LexReader*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::LexReader::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");

    RETVAL = kino_LexReader_new(schema, folder, seg_info);
}
OUTPUT: RETVAL

SV*
look_up_term(self, term_sv)
    kino_LexReader *self;
    SV *term_sv;
CODE:
{
    kino_SegLexicon *seg_lexicon;
    kino_Term *term = NULL;
    MAYBE_EXTRACT_STRUCT(term_sv, term, kino_Term*,
        "KinoSearch::Index::Term");

    seg_lexicon = Kino_LexReader_Look_Up_Term(self, term);
    RETVAL = seg_lexicon == NULL
        ? newSV(0)
        : kobj_to_pobj(seg_lexicon);
    REFCOUNT_DEC(seg_lexicon);
}
OUTPUT: RETVAL

SV*
look_up_field(self, field_name)
    kino_LexReader *self;
    kino_ByteBuf field_name;
CODE:
{
    kino_SegLexicon *seg_lexicon
        = Kino_LexReader_Look_Up_Field(self, &field_name);
    RETVAL = seg_lexicon == NULL
        ? newSV(0)
        : kobj_to_pobj(seg_lexicon);
    REFCOUNT_DEC(seg_lexicon);
}
OUTPUT: RETVAL

SV*
fetch_term_info(self, term_sv)
    kino_LexReader *self;
    SV *term_sv;
CODE:
{
    kino_TermInfo *tinfo;
    kino_Term *term = NULL;
    MAYBE_EXTRACT_STRUCT(term_sv, term, kino_Term*,
        "KinoSearch::Index::Term");

    tinfo = Kino_LexReader_Fetch_Term_Info(self, term);
    RETVAL = tinfo == NULL
        ? newSV(0)
        : kobj_to_pobj(tinfo);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_LexReader *self;
ALIAS:
    get_index_interval       = 6 
    get_skip_interval        = 8
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 6:  retval = newSViv(self->index_interval);
             break;

    case 8:  retval = newSViv(self->skip_interval);
             break;

    END_SET_OR_GET_SWITCH
}

void
close(self)
    kino_LexReader *self;
PPCODE:
    kino_LexReader_close(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::LexReader - Read a segment's Lexicons.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


