use strict;
use warnings;

package KinoSearch::Search::FieldDoc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::ScoreDoc );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        collator => undef,
    );
}
our %instance_vars;

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
    kino_u32_t id = extract_uv(args_hash, SNL("id"));
    float score   = extract_nv(args_hash, SNL("score"));
    kino_FieldDocCollator *collator = extract_obj(args_hash, SNL("collator"),
        "KinoSearch::Search::FieldDocCollator");

    /* build object */
    RETVAL = kino_FieldDoc_new(id, score, collator);
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

See L<KinoSearch> version 0.20_01.

=end devdocs

=cut

