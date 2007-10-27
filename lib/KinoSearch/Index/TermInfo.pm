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
new(class_sv, doc_freq, post_filepos, skip_filepos, index_filepos)
    SV         *class_sv;
    chy_i32_t   doc_freq;
    chy_u64_t   post_filepos;
    chy_u64_t   skip_filepos;
    chy_u64_t   index_filepos;
CODE:
    CHY_UNUSED_VAR(class_sv);
    RETVAL = kino_TInfo_new(doc_freq, post_filepos, skip_filepos,
        index_filepos);
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
    set_post_filepos  = 3
    get_post_filepos  = 4
    set_skip_filepos  = 5
    get_skip_filepos  = 6
    set_index_filepos = 7
    get_index_filepos = 8
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  self->doc_freq = SvIV(ST(1));
             break;

    case 2:  retval = newSViv(self->doc_freq);
             break;

    case 3:  self->post_filepos = SvNV(ST(1));
             break;

    case 4:  retval = newSVnv(self->post_filepos);
             break;

    case 5:  self->skip_filepos = SvNV(ST(1));
             break;

    case 6:  retval = newSVnv(self->skip_filepos);
             break;

    case 7:  self->index_filepos = SvNV(ST(1));
             break;

    case 8:  retval = newSVnv(self->index_filepos);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermInfo - Filepointer/statistical data for a Term.

=head1 SYNOPSIS

    my $tinfo = KinoSearch::Index::TermInfo->new(
        $doc_freq,
        $post_filepos,
        $skip_filepos,
        $index_filepos
    );

=head1 DESCRIPTION

The TermInfo contains pointer data indicating where information about a term
can be found in various files, plus the document frequency of the term.

The index_filepos member variable is only used if the TermInfo is part of the
.lexx stream; it is a filepointer to a locations in the main .lex file.

=head1 METHODS

=head2 new

Constructor.  All arguments are required.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut



