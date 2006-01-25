package KinoSearch::Analysis::Stemmer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

use Lingua::Stem::Snowball qw( stemmers );

our %instance_vars = __PACKAGE__->init_instance_vars( stemmifier => undef, );

# build a list of supported languages.
my %valid_stemmers;
$valid_stemmers{$_} = 1 for stemmers();

sub init_instance {
    my $self = shift;

    # verify language param
    my $language = $self->{language} = lc( $self->{language} );
    $language = $language eq 'nl' ? 'dk' : $language;
    croak("Unsupported language: '$language'")
        unless $valid_stemmers{$language};

    # create instance of Snowball stemmer
    $self->{stemmifier} = Lingua::Stem::Snowball->new( lang => $language );

    # DISABLED, because of segfault-producing bug in
    # Lingua::Stem::Snowball 0.93
    # $self->{stemmifier}->strip_apostrophes(1);
}

sub analyze {
    my ( $self, $field ) = @_;

    # retrieve terms and if there aren't any, bail rather than invoke stem
    my $terms = $field->get_terms;
    return unless @$terms;

    # replace terms with stemmed versions.
    my @stemmed = $self->{stemmifier}->stem($terms);
    s/'$// for @stemmed;    # TODO get rid of this once Snowball is fixed.
    $field->set_terms( \@stemmed );
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
match documents containing 'horses' and 'horsing'.  For more information, see
the documentation for L<Lingua::Stem|Lingua::Stem>.

This class is a wrapper around
L<Lingua::Stem::Snowball|Lingua::Stem::Snowball>, so it supports the same
languages.  

=head1 METHODS 

=head2 new

Create a new stemmer.  Takes a single named parameter, C<language>, which must
be an ISO two-letter code that Lingua::Stem::Snowball understands.

=head1 TODO

Submit patches for Lingua::Stem::Snowball which enhance speed and address
apostrophe-handling issues.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=cut

