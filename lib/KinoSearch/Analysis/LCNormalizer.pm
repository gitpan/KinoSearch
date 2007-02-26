use strict;
use warnings;

package KinoSearch::Analysis::LCNormalizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );
use locale;

BEGIN { __PACKAGE__->init_instance_vars(); }

use KinoSearch::Analysis::Token;
use KinoSearch::Analysis::TokenBatch;

sub analyze {
    my ( $self, $batch ) = @_;

    # lc all of the terms, one by one
    while ( my $token = $batch->next ) {
        $token->set_text( lc( $token->get_text ) );
    }

    $batch->reset;
    return $batch;
}

1;

__END__

=head1 NAME

KinoSearch::Analysis::LCNormalizer - Convert input to lower case.

=head1 SYNOPSIS

    my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;

    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $lc_normalizer, $tokenizer, $stemmer ],
    );

=head1 DESCRIPTION

This class basically says C<lc($foo)> in a longwinded way which
KinoSearch's Analysis apparatus can understand.

=head1 CONSTRUCTOR

=head2 new

Construct a new LCNormalizer.  Takes one labeled parameter, C<language>,
though it's a no-op for now.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut

