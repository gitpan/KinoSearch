package KinoSearch::Analysis::Stopalizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

use Lingua::StopWords;

our %instance_vars = __PACKAGE__->init_instance_vars( stoplist => undef, );

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
        if ( $language =~ /\A(?:da|de|dk|en|es|fi|fr|it|no|pt|ru|sv)\z/xms ) {
            $self->{stoplist} = Lingua::StopWords::getStopWords($language);
        }
        # if no language supplied, create an empty stoplist
        else {
            $self->{stoplist} = {};
        }
    }
}

sub analyze {
    my ( $self, $field ) = @_;
    my $terms    = $field->get_terms;
    my $stoplist = $self->{stoplist};

    # convert stopwords into empty strings
    for (@$terms) {
        $_ = ''
            if $stoplist->{$_};
    }
}

1;

__END__

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
    @tokens = ('i', 'am', 'the', 'walrus');
    
    # after
    @tokens = ('',  '',   '',    'walrus');

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

See L<KinoSearch|KinoSearch> version 0.05_03.

=cut
