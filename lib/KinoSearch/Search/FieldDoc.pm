use strict;
use warnings;

package KinoSearch::Search::FieldDoc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::ScoreDoc );

our %instance_vars = (
    # inherited
    doc_num => undef,
    score   => undef,

    # constructor params
    collator => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::FieldDoc

kino_FieldDoc*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::FieldDoc::instance_vars");
    chy_u32_t doc_num = extract_uv(args_hash, SNL("doc_num"));
    float score       = extract_nv(args_hash, SNL("score"));
    kino_FieldDocCollator *collator = extract_obj(args_hash, SNL("collator"),
        "KinoSearch::Search::FieldDocCollator");

    /* build object */
    RETVAL = kino_FieldDoc_new(doc_num, score, collator);
}
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
