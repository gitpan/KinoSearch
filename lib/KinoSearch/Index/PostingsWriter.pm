use strict;
use warnings;

package KinoSearch::Index::PostingsWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        #constructor params / members
        invindex => undef,
        seg_info => undef,
    );
}
our %instance_vars;

our %add_batch_vars = (
    token_batch => undef,
    field_name  => undef,
    doc_num     => undef,
    doc_boost   => undef,
    length_norm => undef,
);

use KinoSearch::Index::IndexFileNames qw( POSTING_LIST_FORMAT );
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::TermListWriter;
use KinoSearch::Util::SortExternal;

# Bulk add all the postings in a segment to the sort pool.
sub add_segment {
    my ( $self, $seg_reader, $doc_map, $field_num_map ) = @_;
    my $tl_reader = $seg_reader->get_tl_reader;
    my $term_docs = $seg_reader->term_docs;
    $self->_add_segment( $tl_reader, $term_docs, $doc_map, $field_num_map );
}

=for comment

Process all the postings in the sort pool.  Generate the freqs and positions
files.  Hand off data to TermListWriter for the generating the term
dictionaries.

=cut

sub write_postings {
    my ( $self, $segment_metadata ) = @_;

    # sort the serialized postings
    my $sort_pool = $self->_get_sort_pool;
    $sort_pool->sort_all;

    # get a TermListWriter and write postings
    my $tl_writer = KinoSearch::Index::TermListWriter->new(
        invindex => $self->_get_invindex,
        seg_info => $self->_get_seg_info,
    );
    $self->_write_postings($tl_writer);
    $tl_writer->finish;
}

sub finish {
    my $self = shift;
    my %metadata = ( format => POSTING_LIST_FORMAT );
    $self->_get_seg_info->add_metadata( 'posting_list', \%metadata );
    $self->_get_sort_pool()->close;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PostingsWriter      

kino_PostingsWriter*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::PostingsWriter::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");

    RETVAL = kino_PostWriter_new(invindex, seg_info);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_PostingsWriter *self;
ALIAS:
    _get_sort_pool = 2
    _get_invindex  = 4
    _get_seg_info  = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->sort_pool);
             break;

    case 4:  retval = kobj_to_pobj(self->invindex);
             break;

    case 6:  retval = kobj_to_pobj(self->seg_info);
             break;
    
    END_SET_OR_GET_SWITCH
}


void
_write_postings (self, tl_writer)
    kino_PostingsWriter  *self;
    kino_TermListWriter *tl_writer;
PPCODE:
    Kino_PostWriter_Write_Postings(self, tl_writer);

=for comment

Add all the postings in an inverted document to the sort pool.

=cut 

void
add_batch(self, ...)
    kino_PostingsWriter *self;
PPCODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::PostingsWriter::add_batch_vars");
    kino_TokenBatch *batch = (kino_TokenBatch*)extract_obj( args_hash, 
        SNL("token_batch"), "KinoSearch::Analysis::TokenBatch");
    kino_i32_t doc_num     = extract_iv( args_hash, SNL("doc_num") );
    float      doc_boost   = extract_nv( args_hash, SNL("doc_boost") );
    float      length_norm = extract_nv( args_hash, SNL("length_norm") );
    SV *field_name_sv      = extract_sv( args_hash, SNL("field_name") );
    kino_ByteBuf field_name = KINO_BYTEBUF_BLANK;

    SV_TO_TEMP_BB(field_name_sv, field_name);
    
    kino_PostWriter_add_batch(self, batch, &field_name, doc_num, doc_boost,
        length_norm);
}

void
_add_segment(self, tl_reader, term_docs, doc_map, field_num_map_sv)
    kino_PostingsWriter *self;
    kino_TermListReader *tl_reader;
    kino_SegTermDocs *term_docs;
    kino_IntMap   *doc_map;
    SV *field_num_map_sv;
PPCODE:
{
    kino_IntMap *field_num_map = NULL;
    MAYBE_EXTRACT_STRUCT(field_num_map_sv, field_num_map, kino_IntMap*,
        "KinoSearch::Util::IntMap");
    Kino_PostWriter_Add_Segment(self, tl_reader, term_docs, doc_map,
        field_num_map);
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::PostingsWriter - Write postings data to an InvIndex.

=head1 DESCRIPTION

PostingsWriter creates posting lists.  It writes the frequency and and
positional data files, plus feeds data to TermListWriter.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

