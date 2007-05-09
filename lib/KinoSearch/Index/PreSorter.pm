use strict;
use warnings;

package KinoSearch::Index::PreSorter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

use KinoSearch::Util::IntMap;

our %instance_vars = (
    # constructor params
    field   => undef,
    reverse => undef,
);

sub add_segment {
    my ( $self, $seg_reader, $doc_remap ) = @_;
    my $seg_max_doc = $seg_reader->max_doc;
    my $lexicon     = $seg_reader->look_up_field( $self->_get_field );
    my $sort_cache  = $seg_reader->fetch_sort_cache( $self->_get_field );
    _add_seg_data( $self, $seg_max_doc, $lexicon, $sort_cache, $doc_remap );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PreSorter

kino_PreSorter*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::PreSorter::instance_vars");
    SV *field_sv   = extract_sv(args_hash, SNL("field"));
    SV *reverse_sv = extract_sv(args_hash, SNL("reverse"));
    chy_bool_t reverse = SvTRUE(reverse_sv);
    kino_ByteBuf field;
    SV_TO_TEMP_BB(field_sv, field);

    RETVAL = kino_PreSorter_new(&field, reverse);
}
OUTPUT: RETVAL

void
add_val(self, doc_num, val)
    kino_PreSorter *self;
    chy_u32_t doc_num;
    kino_ByteBuf val;
PPCODE:
    Kino_PreSorter_Add_Val(self, doc_num, &val);

kino_IntMap*
gen_remap(self)
    kino_PreSorter *self;
CODE:
    RETVAL = kino_PreSorter_gen_remap(self);
    REFCOUNT_INC(RETVAL);
OUTPUT: RETVAL

void
_add_seg_data(self, seg_max_doc, lexicon, sort_cache, seg_doc_remap_sv)
    kino_PreSorter *self;
    chy_u32_t seg_max_doc;
    kino_SegLexicon *lexicon;
    kino_IntMap *sort_cache;
    SV *seg_doc_remap_sv;
PPCODE:
{
    kino_IntMap *seg_doc_remap = NULL;
    MAYBE_EXTRACT_STRUCT(seg_doc_remap_sv, seg_doc_remap, kino_IntMap*,
        "KinoSearch::Util::IntMap");
    Kino_PreSorter_Add_Seg_Data(self, seg_max_doc, lexicon, 
        sort_cache, seg_doc_remap);
}


void
_set_or_get(self, ...)
    kino_PreSorter *self;
ALIAS:
    _get_field   = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH
    
    case 2:  retval = bb_to_sv(self->field);
             break;

    END_SET_OR_GET_SWITCH
}



__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::PreSorter - Pre-sort documents by a field's value.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
