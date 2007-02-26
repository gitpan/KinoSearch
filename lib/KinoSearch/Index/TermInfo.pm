use strict;
use warnings;

package KinoSearch::Index::TermInfo;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__
__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::TermInfo

kino_TermInfo*
new(class_sv, field_num, doc_freq, post_fileptr, skip_offset, index_fileptr)
    SV         *class_sv;
    kino_i32_t  field_num;
    kino_i32_t  doc_freq;
    kino_u64_t  post_fileptr;
    kino_i32_t  skip_offset;
    kino_u64_t  index_fileptr;
CODE:
    KINO_UNUSED_VAR(class_sv);
    RETVAL = kino_TInfo_new(field_num, doc_freq, post_fileptr, skip_offset,
        index_fileptr);
OUTPUT: RETVAL

void
reset(self)
    kino_TermInfo *self;
PPCODE:
    Kino_TInfo_Reset(self);


void
_set_or_get(self, ...)
    kino_TermInfo *self;
ALIAS:
    set_doc_freq      = 1
    get_doc_freq      = 2
    set_post_fileptr  = 3
    get_post_fileptr  = 4
    set_skip_offset   = 5
    get_skip_offset   = 6
    set_index_fileptr = 7
    get_index_fileptr = 8
    set_field_num     = 9
    get_field_num     = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  self->doc_freq = SvIV(ST(1));
             break;

    case 2:  retval = newSViv(self->doc_freq);
             break;

    case 3:  self->post_fileptr = SvNV(ST(1));
             break;

    case 4:  retval = newSVnv(self->post_fileptr);
             break;

    case 5:  self->skip_offset = SvIV(ST(1));
             break;

    case 6:  retval = newSViv(self->skip_offset);
             break;

    case 7:  self->index_fileptr = SvNV(ST(1));
             break;

    case 8:  retval = newSVnv(self->index_fileptr);
             break;

    case 9:  self->field_num = SvIV(ST(1));
             break;

    case 10: retval = newSViv(self->field_num);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermInfo - Filepointer/statistical data for a Term.

=head1 SYNOPSIS

    my $tinfo = KinoSearch::Index::TermInfo->new(
        $field_num,
        $doc_freq,
        $post_fileptr,
        $skip_offset,
        $index_fileptr
    );

=head1 DESCRIPTION

The TermInfo contains pointer data indicating where a term can be found in
various files, plus the document frequency of the term.

The index_fileptr member variable is only used if the TermInfo is part of the
.tlx stream; it is a filepointer to a locations in the main .tl file.

=head1 METHODS

=head2 new

Constructor.  All arguments are required.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut



