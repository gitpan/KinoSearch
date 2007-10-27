use strict;
use warnings;

package KinoSearch::Posting::RichPosting;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Posting::ScorePosting );

our %instance_vars = (
    # constructor params
    similarity => undef,
);

package KinoSearch::Posting::RichPostingScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Posting::ScorePostingScorer );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Posting::RichPosting

kino_RichPosting*
new(class_name, ...)
    const classname_char *class_name;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Posting::RichPosting::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(args_hash, 
        SNL("similarity"), "KinoSearch::Search::Similarity");
    CHY_UNUSED_VAR(class_name);
    RETVAL = kino_RichPost_new(sim);
}
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Posting::RichPosting - Posting with per-position boost.

=head1 SYNOPSIS

    # used indirectly, by specifying in FieldSpec subclass
    package MySchema::Category;
    use base qw( KinoSearch::FieldSpec::text );
    sub posting_type { 'KinoSearch::Posting::RichPosting' }

=head1 DESCRIPTION

RichPosting is similar to L<ScorePosting|KinoSearch::Posting::ScorePosting>,
but weighting is per-position rather than per-field.  To exploit this, you need a
custom L<Analyzer|KinoSearch::Analysis::Analyzer> which assigns varying
boosts to individual L<Token|KinoSearch::Analysis::Token> objects.

A typical application for RichPosting is an HTMLAnalyzer which assigns
boost based on the visual size and weight of the marked up text: H1
blocks get the greatest weight, H2 blocks almost as much, etc.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
