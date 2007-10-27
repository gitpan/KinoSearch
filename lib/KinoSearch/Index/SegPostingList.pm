use strict;
use warnings;

package KinoSearch::Index::SegPostingList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::PostingList );

our %instance_vars = (
    # constructor params
    seg_reader => undef,
    field      => undef,

    # additional constructor params for C
    schema        => undef,
    folder        => undef,
    seg_info      => undef,
    deldocs       => undef,
    skip_interval => undef,
    lex_reader    => undef,
);

use KinoSearch::Posting::ScorePosting;

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );
    my $seg_reader = $args{seg_reader};

    my $self = $class->_new(
        lex_reader    => $seg_reader->get_lex_reader,
        schema        => $seg_reader->get_schema,
        seg_info      => $seg_reader->get_seg_info,
        field         => $args{field},
        folder        => $seg_reader->get_comp_file_reader,
        deldocs       => $seg_reader->get_deldocs,
        skip_interval => $seg_reader->get_skip_interval,
    );

    return $self;
}

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::SegPostingList

kino_SegPostingList*
_new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SegPostingList::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    kino_DelDocs *deldocs = (kino_DelDocs*)extract_obj(
        args_hash, SNL("deldocs"), "KinoSearch::Index::DelDocs");
    kino_LexReader *lex_reader = (kino_LexReader*)extract_obj(
        args_hash, SNL("lex_reader"), "KinoSearch::Index::LexReader");
    chy_u32_t skip_interval = extract_iv(args_hash, SNL("skip_interval"));
    kino_ByteBuf field;
    SV  *field_sv = extract_sv(args_hash, SNL("field"));
    SV_TO_TEMP_BB(field_sv, field);

    RETVAL = kino_SegPList_new(schema, folder, seg_info, &field, lex_reader,
        deldocs, skip_interval);
}
OUTPUT: RETVAL

void
set_doc_base(self, doc_base);
    kino_SegPostingList *self;
    chy_u32_t doc_base
PPCODE:
    Kino_SegPList_Set_Doc_Base(self, doc_base);

	
	
=for comment

Testing only.

=cut

void
_set_or_get(self, ...)
    kino_SegPostingList *self;
ALIAS:
    _get_post_stream = 2
    _get_count       = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->post_stream);
             break;

    case 4:  retval = newSViv(self->count);
             break;
    
    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegPostingList - Single-segment PostingList.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
