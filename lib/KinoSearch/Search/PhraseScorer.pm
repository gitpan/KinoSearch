use strict;
use warnings;

package KinoSearch::Search::PhraseScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

our %instance_vars = (
    # constructor params
    similarity     => undef,
    weight         => undef,
    weight_value   => undef,
    posting_lists  => undef,
    phrase_offsets => undef,
    slop           => 0,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::PhraseScorer

kino_PhraseScorer*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::PhraseScorer::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(
        args_hash, SNL("similarity"), "KinoSearch::Search::Similarity");
    kino_VArray *plists = (kino_VArray*)extract_obj(
        args_hash, SNL("posting_lists"), "KinoSearch::Util::VArray");
    kino_VArray *phrase_offsets = (kino_VArray*)extract_obj(
        args_hash, SNL("phrase_offsets"), "KinoSearch::Util::VArray");
    SV *weight_sv    = extract_sv(args_hash, SNL("weight"));
    float weight_val = extract_nv(args_hash, SNL("weight_value"));
    chy_u32_t slop   = extract_uv(args_hash, SNL("slop"));

    /* create object */
    RETVAL = kino_PhraseScorer_new(sim, plists, phrase_offsets,
        newSVsv(weight_sv), weight_val, slop);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::PhraseScorer - Scorer for PhraseQuery.

=head1 DESCRIPTION 

Score phrases.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
