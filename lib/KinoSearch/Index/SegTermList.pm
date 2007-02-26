use strict;
use warnings;

package KinoSearch::Index::SegTermList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermList );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        schema    => undef,
        folder    => undef,
        seg_info  => undef,
        is_index  => 0,
        tl_cache  => undef,
        field     => undef,
    );
}
our %instance_vars;

use KinoSearch::Index::Term;
use KinoSearch::Index::TermInfo;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::SegTermList 

kino_SegTermList*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SegTermList::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");
    kino_bool_t is_index = extract_iv(args_hash, SNL("is_index"));
    SV *tl_cache_sv = extract_sv(args_hash, SNL("tl_cache"));
    kino_SegTermListCache *tl_cache = NULL;
    SV *field_sv = extract_sv(args_hash, SNL("field"));
    kino_ByteBuf field = KINO_BYTEBUF_BLANK;

    if (SvOK(tl_cache_sv)) {
        EXTRACT_STRUCT(tl_cache_sv, tl_cache, kino_SegTermListCache*, 
            "KinoSearch::Index::SegTermListCache");
    }

    if (SvOK(field_sv))
        SV_TO_TEMP_BB(field_sv, field);
    else 
        CONFESS("Missing required param 'field'");


    RETVAL = kino_SegTermList_new(schema, folder, seg_info, &field, 
        tl_cache, is_index);
}
OUTPUT: RETVAL

kino_i32_t
get_field_num(self);
    kino_SegTermList *self;
CODE:
    RETVAL = Kino_SegTermList_Get_Field_Num(self);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_SegTermList *self;
ALIAS:
    get_size                 = 2  
    get_term_info            = 4
    is_index                 = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSViv(self->size); 
             break;

    case 4:  retval = kobj_to_pobj(Kino_SegTermList_Get_Term_Info(self));
             break;

    case 10: retval = newSViv(self->is_index);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegTermList - Single-segment TermList.

=head1 DESCRIPTION

Single-segment implementation of KinoSearch::Index::TermList.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


