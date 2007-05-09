use strict;
use warnings;

package KinoSearch::Search::Tally;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::Tally

void
_set_or_get(self, ...)
    kino_Tally *self;
ALIAS:
    get_score   = 2
    get_prox    = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVnv(self->score);
             break;
    case 4:  {
                AV *out_av = newAV();
                chy_u32_t i;
                for (i = 0; i < self->num_prox; i++) {
                    av_push( out_av, newSVnv(self->prox[i]) );
                }
                retval = newRV_noinc( (SV*)out_av );
             }
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::Tally - Scoring info, attached to a Scorer.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs

=cut

