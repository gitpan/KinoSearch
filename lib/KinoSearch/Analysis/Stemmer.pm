package KinoSearch::Analysis::Stemmer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer Exporter );

use Lingua::Stem::Snowball qw( stemmers );
our @EXPORT_OK = qw( %supported_languages );

our %instance_vars = __PACKAGE__->init_instance_vars( stemmifier => undef, );

# build a list of supported languages.
my %supported_languages;
$supported_languages{$_} = 1 for stemmers();

sub init_instance {
    my $self = shift;

    # verify language param
    my $language = $self->{language} = lc( $self->{language} );
    croak("Unsupported language: '$language'")
        unless $supported_languages{$language};

    # create instance of Snowball stemmer
    $self->{stemmifier} = Lingua::Stem::Snowball->new( lang => $language );
}

sub analyze {
    my ( $self, $token_batch ) = @_;

    # replace terms with stemmed versions.
    $self->{stemmifier}->stem_in_place( $token_batch->get_all_texts );

    return $token_batch;
}

1;

__END__

=head1 NAME

KinoSearch::Analysis::Stemmer - reduce related words to a shared root

=head1 SYNOPSIS

    my $stemmer = KinoSearch::Analysis::Stemmer->new( language => 'es' );
    
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $lc_normalizer, $tokenizer, $stemmer ],
    );

=head1 DESCRIPTION

Stemming reduces words to a root form.  For instance, "horse", "horses",
and "horsing" all become "hors" -- so that a search for 'horse' will also
match documents containing 'horses' and 'horsing'.  

This class is a wrapper around
L<Lingua::Stem::Snowball|Lingua::Stem::Snowball>, so it supports the same
languages.  

=head1 METHODS 

=head2 new

Create a new stemmer.  Takes a single named parameter, C<language>, which must
be an ISO two-letter code that Lingua::Stem::Snowball understands.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.06.

=cut

