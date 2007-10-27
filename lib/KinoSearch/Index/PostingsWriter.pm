use strict;
use warnings;

package KinoSearch::Index::PostingsWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    #constructor params / members
    invindex   => undef,
    seg_info   => undef,
    pre_sorter => undef,
    mem_thresh => 0x1000000,    # 16 MiB
);

our %add_batch_vars = (
    token_batch => undef,
    field_name  => undef,
    doc_num     => undef,
    doc_boost   => undef,
    length_norm => undef,
);

use KinoSearch::Index::TermInfo;
use KinoSearch::Index::LexWriter;

sub new {
    my $ignore = shift;
    confess kerror unless verify_args( \%instance_vars, @_ );
    our %args = ( %instance_vars, @_ );
    my ( $invindex, $seg_info ) = @args{qw( invindex seg_info )};

    my $lex_writer = KinoSearch::Index::LexWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );

    return _new( $invindex, $seg_info, $lex_writer,
        @args{qw( pre_sorter mem_thresh )} );
}

# Bulk add all terms and postings in a segment.
sub add_segment {
    my ( $self, $seg_reader, $doc_map ) = @_;
    my $other_seg_info = $seg_reader->get_seg_info;
    my $other_folder   = $seg_reader->get_comp_file_reader;
    $self->_add_seg_data( $other_folder, $other_seg_info, $doc_map );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PostingsWriter      

kino_PostingsWriter*
_new(invindex, seg_info, lex_writer, pre_sorter_sv, mem_thresh)
    kino_InvIndex *invindex;
    kino_SegInfo  *seg_info;
    kino_LexWriter *lex_writer;
    SV *pre_sorter_sv;
    chy_u32_t mem_thresh;
CODE:
{
    kino_PreSorter *pre_sorter = NULL;
    MAYBE_EXTRACT_STRUCT(pre_sorter_sv, pre_sorter, kino_PreSorter*, 
        "KinoSearch::Index::PreSorter");
    RETVAL = kino_PostWriter_new(invindex, seg_info, lex_writer, 
        pre_sorter, mem_thresh);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_PostingsWriter *self;
ALIAS:
    _get_invindex  = 2
    _get_seg_info  = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->invindex);
             break;

    case 4:  retval = kobj_to_pobj(self->seg_info);
             break;
    
    END_SET_OR_GET_SWITCH
}

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
    chy_i32_t  doc_num     = extract_iv( args_hash, SNL("doc_num") );
    float      doc_boost   = extract_nv( args_hash, SNL("doc_boost") );
    float      length_norm = extract_nv( args_hash, SNL("length_norm") );
    SV *field_name_sv      = extract_sv( args_hash, SNL("field_name") );
    kino_ByteBuf field_name = KINO_BYTEBUF_BLANK;

    SV_TO_TEMP_BB(field_name_sv, field_name);
    
    kino_PostWriter_add_batch(self, batch, &field_name, doc_num, doc_boost,
        length_norm);
}

void
_add_seg_data(self, other_folder, other_seg_info, doc_map)
    kino_PostingsWriter *self;
    kino_Folder         *other_folder;
    kino_SegInfo        *other_seg_info;
    kino_IntMap         *doc_map;
PPCODE:
    Kino_PostWriter_Add_Seg_Data(self, other_folder, other_seg_info, doc_map);

void
finish(self)
    kino_PostingsWriter *self;
PPCODE:
    Kino_PostWriter_Finish(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::PostingsWriter - Write postings data to an InvIndex.

=head1 DESCRIPTION

PostingsWriter creates posting lists.  It writes the frequency and and
positional data files, plus feeds data to LexWriter.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
