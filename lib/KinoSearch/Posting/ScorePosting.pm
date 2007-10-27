use strict;
use warnings;

package KinoSearch::Posting::ScorePosting;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Posting::MatchPosting );

our %instance_vars = (
    # constructor params
    similarity => undef,
);

package KinoSearch::Posting::ScorePostingScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::TermScorer );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Posting::ScorePosting

kino_ScorePosting*
new(class_name, ...)
    const classname_char *class_name;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Posting::ScorePosting::instance_vars");
    kino_Similarity *sim = (kino_Similarity*)extract_obj(args_hash, 
        SNL("similarity"), "KinoSearch::Search::Similarity");
    CHY_UNUSED_VAR(class_name);
    RETVAL = kino_ScorePost_new(sim);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_ScorePosting *self;
ALIAS:
    get_freq       = 2
    get_impact     = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVuv(self->freq);
             break;

    case 4:  retval = newSVnv(self->impact);
             break;

    END_SET_OR_GET_SWITCH
}

SV*
get_prox(self)
    kino_ScorePosting *self;
CODE:
{
    AV *out_av            = newAV();
    chy_u32_t *positions  = self->prox;
    chy_u32_t i;

    for (i = 0; i < self->freq; i++) {
        SV *pos_sv = newSVuv(positions[i]);
        av_push(out_av, pos_sv);
    }

    RETVAL = newRV_noinc((SV*)out_av);
}
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Posting::ScorePosting - Default posting type.

=head1 SYNOPSIS

    # used indirectly, by specifying in FieldSpec subclass
    package MySchema::Category;
    use base qw( KinoSearch::FieldSpec::text );
    # (it's the default, so you don't need to spec it)
    # sub posting_type { 'KinoSearch::Posting::ScorePosting' }

=head1 DESCRIPTION

ScorePosting is the default posting format in KinoSearch.  The term-document
pairing used by MatchPosting is supplemented by additional frequency,
position, and impact (weighting) information.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
