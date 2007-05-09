use strict;
use warnings;

package KinoSearch::Search::ScoreDoc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    doc_num => undef,
    score   => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::ScoreDoc

kino_ScoreDoc*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::ScoreDoc::instance_vars");
    chy_u32_t doc_num  = extract_uv(args_hash, SNL("doc_num"));
    float score   = extract_nv(args_hash, SNL("score"));

    /* build object */
    RETVAL = kino_ScoreDoc_new(doc_num, score);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_ScoreDoc *self;
ALIAS:
    set_doc_num      = 1
    get_doc_num      = 2
    set_score        = 3
    get_score        = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  self->doc_num = SvIV(ST(1));
             break;

    case 2:  retval = newSViv(self->doc_num);
             break;

    case 3:  self->score = SvNV(ST(1));
             break;

    case 4:  retval = newSVnv(self->score);
             break;

    END_SET_OR_GET_SWITCH
}

kino_ScoreDoc*
deserialize(class_name, serialized)
    const classname_char *class_name;
    kino_ViewByteBuf serialized;
CODE:
    if (strcmp(class_name, "KinoSearch::Search::ScoreDoc") != 0)
        CONFESS("deserialize can't be inherited");
    RETVAL = kino_ScoreDoc_deserialize(&serialized);
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::ScoreDoc - A doc number and a score.

=head1 DESCRIPTION 

It's a doc number and a score.  That's it.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs

=cut
