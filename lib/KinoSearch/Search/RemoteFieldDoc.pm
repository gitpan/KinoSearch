use strict;
use warnings;

package KinoSearch::Search::RemoteFieldDoc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::ScoreDoc ); # note: not FieldDoc

our %instance_vars = (
    # inherited
    doc_num => undef,
    score   => undef,

    # constructor params
    field_vals => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::RemoteFieldDoc

kino_RemoteFieldDoc*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::RemoteFieldDoc::instance_vars");
    chy_u32_t doc_num  = extract_uv(args_hash, SNL("doc_num"));
    float score   = extract_nv(args_hash, SNL("score"));
    kino_VArray *field_vals = extract_obj(args_hash, SNL("field_vals"),
        "KinoSearch::Util::VArray");

    /* build object */
    RETVAL = kino_RemoteFieldDoc_new(doc_num, score, field_vals);
}
OUTPUT: RETVAL

kino_RemoteFieldDoc*
deserialize(class_name, serialized)
    const classname_char *class_name;
    kino_ViewByteBuf serialized;
CODE:
    if (strcmp(class_name, "KinoSearch::Search::RemoteFieldDoc") != 0)
        CONFESS("deserialize can't be inherited");
    RETVAL = kino_RemoteFieldDoc_deserialize(&serialized);
OUTPUT: RETVAL

kino_VArray*
get_field_vals(self)
    kino_RemoteFieldDoc *self
CODE:
    RETVAL = REFCOUNT_INC(self->field_vals);
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::RemoteFieldDoc - Kludge.

=head1 DESCRIPTION 

This class is a temporary kludge to enable sorting under MultiSearcher.  May
it die a quick and painless death.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs

=cut
