use strict;
use warnings;

package KinoSearch::Index::TermListReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        schema   => undef,
        folder   => undef,
        seg_info => undef,
    );
}
our %instance_vars;

use KinoSearch::Index::Term;
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::SegTermList;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::TermListReader 

kino_TermListReader*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::TermListReader::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");

    RETVAL = kino_TLReader_new(schema, folder, seg_info);
}
OUTPUT: RETVAL

SV*
field_terms(self, term_sv)
    kino_TermListReader *self;
    SV *term_sv;
CODE:
{
    kino_Term *term = NULL;
    kino_SegTermList *seg_term_list;
    if (SvOK(term_sv)) {
        EXTRACT_STRUCT(term_sv, term, kino_Term*,
            "KinoSearch::Index::Term");
    }
    seg_term_list = Kino_TLReader_Field_Terms(self, term);
    RETVAL = seg_term_list == NULL
        ? newSV(0)
        : kobj_to_pobj(seg_term_list);
    REFCOUNT_DEC(seg_term_list);
}
OUTPUT: RETVAL

SV*
start_field_terms(self, field_name)
    kino_TermListReader *self;
    kino_ByteBuf field_name;
CODE:
{
    kino_SegTermList *seg_term_list
        = Kino_TLReader_Start_Field_Terms(self, &field_name);
    RETVAL = seg_term_list == NULL
        ? newSV(0)
        : kobj_to_pobj(seg_term_list);
    REFCOUNT_DEC(seg_term_list);
}
OUTPUT: RETVAL

SV*
fetch_term_info(self, term_sv)
    kino_TermListReader *self;
    SV *term_sv;
CODE:
{
    kino_Term *term = NULL;
    kino_TermInfo *tinfo;
    if (SvOK(term_sv)) {
        EXTRACT_STRUCT(term_sv, term, kino_Term*,
            "KinoSearch::Index::Term");
    }
    tinfo = Kino_TLReader_Fetch_Term_Info(self, term);
    RETVAL = tinfo == NULL
        ? newSV(0)
        : kobj_to_pobj(tinfo);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_TermListReader *self;
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
    kino_TermListReader *self;
PPCODE:
    kino_TLReader_close(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermListReader - Read a segment's term lists.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


