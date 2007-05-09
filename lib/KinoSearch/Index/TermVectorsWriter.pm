use strict;
use warnings;

package KinoSearch::Index::TermVectorsWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params / members
    invindex => undef,
    seg_info => undef,
);

sub add_doc_vec {
    my ( $self, $doc_vec ) = @_;
    my $tv_out  = $self->_get_tv_out;
    my $tvx_out = $self->_get_tvx_out;
    my @fields  = $doc_vec->get_field_names;

    # remember file pointer
    my $filepos = $tv_out->stell;

    # write num_fields
    $tv_out->lu_write( 'V', scalar @fields );

    # write field numbers and field strings
    for my $field_name (@fields) {
        $tv_out->lu_write( 'TT', $field_name,
            $doc_vec->field_string($field_name) );
    }

    # write index data
    my $len = $tv_out->stell - $filepos;
    $tvx_out->lu_write( 'QQ', $filepos, $len );
}

sub add_segment {
    my ( $self, $seg_reader, $doc_map ) = @_;
    my $tv_reader = $seg_reader->get_tv_reader;
    $self->_add_segment( $tv_reader, $doc_map, $seg_reader->max_doc );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermVectorsWriter

kino_TermVectorsWriter*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::TermVectorsWriter::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");

    RETVAL = kino_TVWriter_new(invindex, seg_info);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_TermVectorsWriter *self;
ALIAS:
    _get_tv_out   = 4
    _get_tvx_out  = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 4:  retval = kobj_to_pobj(self->tv_out);
             break;

    case 6:  retval = kobj_to_pobj(self->tvx_out);
             break;

    END_SET_OR_GET_SWITCH
}

void 
_add_segment(self, tv_reader, doc_map, max_doc)
    kino_TermVectorsWriter *self;
    kino_TermVectorsReader *tv_reader;
    kino_IntMap *doc_map;
    chy_u32_t max_doc;
PPCODE:
    kino_TVWriter_add_segment(self, tv_reader, doc_map, max_doc);

SV*
tv_string(self, batch)
    kino_TermVectorsWriter *self;
    kino_TokenBatch *batch;
CODE:
{
    kino_ByteBuf *bb = Kino_TVWriter_TV_String(self, batch);
    RETVAL = bb_to_sv(bb);
    REFCOUNT_DEC(bb);
}
OUTPUT: RETVAL
    

void
finish(self, doc_remap_sv) 
    kino_TermVectorsWriter *self;
    SV *doc_remap_sv;
PPCODE:
{
    kino_IntMap *doc_remap = NULL;
    MAYBE_EXTRACT_STRUCT(doc_remap_sv, doc_remap, kino_IntMap*,
        "KinoSearch::Util::IntMap");
    Kino_TVWriter_Finish(self, doc_remap);
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermVectorsWriter - Add term vectors to index.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
