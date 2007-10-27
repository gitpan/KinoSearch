use strict;
use warnings;

package KinoSearch::Posting::MatchPosting;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Posting );

our %instance_vars = (
    # constructor params
    similarity => undef,
);

package KinoSearch::Posting::MatchPostingScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::TermScorer );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Posting::MatchPosting

kino_MatchPosting*
new(class_name, ...)
    const classname_char *class_name;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Posting::MatchPosting::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(args_hash, 
        SNL("similarity"), "KinoSearch::Search::Similarity");
    CHY_UNUSED_VAR(class_name);
    RETVAL = kino_MatchPost_new(sim);
}
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Posting::MatchPosting - Match but not score documents.

=head1 TODO

This class is not yet fully implemented.

=head1 SYNOPSIS

    # used indirectly, by specifying in FieldSpec subclass
    package MySchema::Category;
    use base qw( KinoSearch::FieldSpec::text );
    sub posting_type { 'KinoSearch::Posting::MatchPosting' }

=head1 DESCRIPTION

Use MatchPosting for fields which only need to be matched, not scored.  For
instance, if you need to determine that that a query matches a particular
category, but don't want the match to contribute to the document score, use
MatchPosting for the field.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
