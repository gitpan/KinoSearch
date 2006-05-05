package KinoSearch::Analysis::Stopalizer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        stoplist => undef,
    );
}

use KinoSearch::Analysis::Stemmer qw( %supported_languages );
use Lingua::StopWords;

sub init_instance {
    my $self     = shift;
    my $language = $self->{language} = lc( $self->{language} );

    # verify a supplied stoplist
    if ( defined $self->{stoplist} ) {
        croak("stoplist must be a hashref")
            unless reftype( $self->{stoplist} ) eq 'HASH';
    }
    else {
        # create a stoplist if language was supplied
        if ( exists $supported_languages{$language} ) {
            $self->{stoplist} = Lingua::StopWords::getStopWords($language);
        }
        # if no language supplied, create an empty stoplist
        else {
            $self->{stoplist} = {};
        }
    }
}

1;

__END__

__XS__

TokenBatch*
analyze(self_hash, batch)
    HV         *self_hash;
    TokenBatch *batch;
CODE:
    RETVAL = Kino_Stopalizer_analyze(self_hash, batch);
OUTPUT: RETVAL
    
__H__

#ifndef H_KINOSEARCH_ANALYSIS_STOPALIZER
#define H_KINOSEARCH_ANALYSIS_STOPALIZER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchAnalysisTokenBatch.h"
#include "KinoSearchUtilVerifyArgs.h"

TokenBatch* Kino_Stopalizer_analyze(HV*, TokenBatch*);

#endif /* include guard */

__C__

#include "KinoSearchAnalysisStopalizer.h"

TokenBatch*
Kino_Stopalizer_analyze(HV* self_hash, TokenBatch *batch) {
    SV **sv_ptr;
    HV  *stoplist_hv;

    sv_ptr = hv_fetch(self_hash, "stoplist", 8, 0);
    if (sv_ptr == NULL)
        Kino_confess("no element 'stoplist'");
    if (!SvROK(*sv_ptr))
        Kino_confess("not a hashref");
    stoplist_hv = (HV*)SvRV(*sv_ptr);
    Kino_Verify_extract_arg(self_hash, "stoplist", 8);

    while (batch->next(batch)) {
        if (hv_exists_ent(stoplist_hv, batch->get_text(batch), 0)) {
            SV *empty_string_sv = newSVpvn("", 0);
            batch->set_text(batch, empty_string_sv);
        }
    }
    return batch;
}
    
__POD__

=head1 NAME

KinoSearch::Analysis::Stopalizer - suppress a "stoplist" of common words

=head1 SYNOPSIS

    my $stopalizer = KinoSearch::Analysis::Stopalizer->new(
        language => 'fr',
    );
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $lc_normalizer, $tokenizer, $stopalizer, $stemmer ],
    );

=head1 DESCRIPTION

A "stoplist" is collection of "stopwords": words which are common enough to be
of little value when determining search results.  For example, so many
documents in English contain "the", "if", and "maybe" that it may improve both
performance and relevance to block them.

    # before
    @token_texts = ('i', 'am', 'the', 'walrus');
    
    # after
    @token_texts = ('',  '',   '',    'walrus');

=head1 CONSTRUCTOR

=head2 new

    my $stopalizer = KinoSearch::Analysis::Stopalizer->new(
        language => 'de',
    );
    
    # or...
    my $stopalizer = KinoSearch::Analysis::Stopalizer->new(
        stoplist => \%stoplist,
    );


new() takes two possible parameters, C<language> and C<stoplist>.  If
C<stoplist> is supplied, it will be used, overriding the behavior indicated by
the value of C<language>.

=over

=item

B<stoplist> - must be a hashref, with stopwords as the keys of the hash and
values set to 1.

=item

B<language> - must be the ISO code for a language.  Loads a default stoplist
supplied by L<Lingua::StopWords|Lingua::StopWords>.

=back

=head1 SEE ALSO

L<Lingua::StopWords|Lingua::StopWords>

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.10.

=cut

