use strict;
use warnings;

package KinoSearch::Analysis::Stopalizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        stoplist => undef,
    );
}

use Lingua::StopWords;

sub init_instance {
    my $self     = shift;
    my $language = $self->{language} = lc( $self->{language} );

    # verify a supplied stoplist
    if ( defined $self->{stoplist} ) {
        confess("stoplist must be a hashref")
            unless reftype( $self->{stoplist} ) eq 'HASH';
    }
    else {
        # create a stoplist if language was supplied
        if ( $language =~ /^(?:da|de|en|es|fi|fr|it|nl|no|pt|ru|sv)$/ ) {
            $self->{stoplist}
                = Lingua::StopWords::getStopWords( $language, 'UTF-8' );
        }
        else {
            confess "Invalid language: '$language'";
        }
    }
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Analysis::Stopalizer

SV*
analyze(self_hash, batch)
    HV *self_hash;
    kino_TokenBatch *batch;
CODE:
{
    SV *stoplist_ref = extract_sv(self_hash, SNL("stoplist"));
    HV  *stoplist_hv = (HV*)SvRV(stoplist_ref);
    kino_Token *token;

    while ((token = Kino_TokenBatch_Next(batch)) != NULL) {
        if (hv_exists(stoplist_hv, token->text, token->len)) {
            token->len = 0;
        }
    }

    Kino_TokenBatch_Reset(batch);

    SvREFCNT_inc( ST(1) );
    RETVAL = ST(1);
}
OUTPUT: RETVAL
    
__POD__

=head1 NAME

KinoSearch::Analysis::Stopalizer - Suppress a "stoplist" of common words.

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
supplied by L<Lingua::StopWords>.

=back

=head1 SEE ALSO

L<Lingua::StopWords>

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut

