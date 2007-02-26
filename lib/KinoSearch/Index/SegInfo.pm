use strict;
use warnings;

package KinoSearch::Index::SegInfo;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

use Time::HiRes;

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        seg_name => undef,
        fspecs   => undef,
        metadata => undef,
    );
}
our %instance_vars;

use KinoSearch::Util::CClass qw( to_kino to_perl );

sub add_metadata {
    my ( $self, $key, $val ) = @_;
    $self->_add_metadata( $key, to_kino($val) );
}

sub extract_metadata {
    my ( $self, $key ) = @_;
    return to_perl( $self->_extract_metadata($key) );
}

1;

__END__

__XS__

MODULE = KinoSearch  PACKAGE = KinoSearch::Index::SegInfo

kino_SegInfo*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SegInfo::instance_vars");
    SV *metadata_sv = extract_sv(args_hash, SNL("metadata"));
    SV *seg_name_sv = extract_sv(args_hash, SNL("seg_name"));
    SV *fspecs_sv   = extract_sv(args_hash, SNL("fspecs"));
    kino_ByteBuf seg_name = KINO_BYTEBUF_BLANK;
    kino_Hash *metadata   = NULL;
    kino_Hash *fspecs     = NULL;

    SV_TO_TEMP_BB(seg_name_sv, seg_name);
    if (SvOK(metadata_sv)) {
        EXTRACT_STRUCT(metadata_sv, metadata, kino_Hash*,
            "KinoSearch::Util::Hash");
    }
    if (SvOK(fspecs_sv)) {
        EXTRACT_STRUCT(fspecs_sv, fspecs, kino_Hash*,
            "KinoSearch::Util::Hash");
    }

    RETVAL = kino_SegInfo_new(&seg_name, fspecs, metadata);
}
OUTPUT: RETVAL

void
increment_doc_count(self)
    kino_SegInfo *self;
PPCODE:
    self->doc_count++;

SV*
generate_field_num_map(self, other)
    kino_SegInfo *self;
    kino_SegInfo *other;
CODE:
{
    kino_IntMap *map = Kino_SegInfo_Generate_Field_Num_Map(self, other);
    RETVAL = map == NULL
        ? newSV(0)
        : kobj_to_pobj(map);
    REFCOUNT_DEC(map);
}
OUTPUT: RETVAL

void
_add_metadata(self, key_sv, val)
    kino_SegInfo *self;
    SV *key_sv;
    kino_Obj *val;
PPCODE:
{
    STRLEN len;
    char *key = SvPV(key_sv, len);
    Kino_SegInfo_Add_Metadata(self, key, len, val);
}
    

kino_Obj*
_extract_metadata(self, key_sv)
    kino_SegInfo *self;
    SV *key_sv;
CODE:
{
    STRLEN len;
    char *key = SvPV(key_sv, len);
    RETVAL = Kino_SegInfo_Extract_Metadata(self, key, len);
    REFCOUNT_INC(RETVAL);
}
OUTPUT: RETVAL

kino_Hash*
get_metadata(self)
    kino_SegInfo *self;
CODE:
    RETVAL = Kino_SegInfo_Get_Metadata(self);
    REFCOUNT_INC(RETVAL);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_SegInfo *self;
ALIAS:
    get_seg_name  = 2
    set_doc_count = 3
    get_doc_count = 4
    _get_metadata_no_update = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = bb_to_sv(self->seg_name);
             break;

    case 3:  self->doc_count = SvUV( ST(1) );
             break;

    case 4:  retval = newSVuv(self->doc_count);
             break;

    case 6:  retval = kobj_to_pobj(self->metadata);
             break;

    END_SET_OR_GET_SWITCH
}

SV*
field_name(self, field_num)
    kino_SegInfo *self;
    kino_i32_t    field_num;
CODE:
{
    kino_ByteBuf *name = Kino_SegInfo_Field_Name(self, field_num);
    RETVAL = bb_to_sv(name);
}
OUTPUT: RETVAL

SV*
field_num(self, field_name)
    kino_SegInfo *self;
    kino_ByteBuf  field_name;
CODE:
{
    kino_i32_t num = Kino_SegInfo_Field_Num(self, &field_name);
    RETVAL = num == -1 
        ? newSV(0)
        : newSViv(num);
}
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Index::SegInfo - Warehouse for information about a segment.

=head1 DESCRIPTION

A SegInfo serves as a central repository for information about a segment.

The "metadata" member var is a space for other writers to lodge their own
data, which will get serialized within the segments_XXX.yaml file, then
retrieve it later.  They must not access data they did not write within the
hash structure, though.  

Since metadata is a shared namespace, SegInfo must be careful about what data
it puts there itself.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

