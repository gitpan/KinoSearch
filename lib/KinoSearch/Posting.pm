use strict;
use warnings;

package KinoSearch::Posting;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Stepper );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Posting

void
_set_or_get(self, ...)
    kino_Posting *self;
ALIAS:
    get_doc_num   = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = self->doc_num == KINO_DOC_NUM_SENTINEL 
                 ? &PL_sv_undef
                 : newSVuv(self->doc_num);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=head1 NAME

KinoSearch::Posting - Base class for Postings.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

A Posting, in KinoSearch, is a vessel which stores information about a
term-document match.  See L<KinoSearch::Docs::IRTheory> for the
academic definition of "posting" or you'll be mighty confused.

Subclasses include L<MatchPosting|KinoSearch::Posting::MatchPosting>, the
simplest posting format, and
L<ScorePosting|KinoSearch::Posting::ScorePosting>, the default.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut


