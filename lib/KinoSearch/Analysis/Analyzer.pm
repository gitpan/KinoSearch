use strict;
use warnings;

package KinoSearch::Analysis::Analyzer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        language => '',
    );
}

use KinoSearch::Analysis::TokenBatch;

# usage: $token_batch = $analyzer->analyze($token_batch);
sub analyze { return $_[1] }

# private convenience method -- skip the tokenbatch part
sub analyze_raw {
    my ( $self, $text ) = @_;
    my $batch = KinoSearch::Analysis::TokenBatch->new( text => $text );

    $batch = $self->analyze($batch);

    my @out;
    while ( my $token = $batch->next ) {
        push @out, $token->get_text;
    }

    return @out;
}

1;

__END__

=head1 NAME

KinoSearch::Analysis::Analyzer - Base class for analyzers.

=head1 SYNOPSIS

    # abstract base class -- must be subclassed

    package MyAnalyzer;

    sub analyze {
        my ( $self, $token_batch ) = @_;

        while ( my $token = $token_batch->next ) {
            my $new_text = transform( $token->get_text );
            $token->set_text($new_text);
        }

        return $token_batch;
    }

    sub transform {
        # ...
    }

=head1 DESCRIPTION

In KinoSearch, an Analyzer is a filter which processes text, transforming it
from one form into another.  For instance, an analyzer might break up a long
text into smaller pieces (L<Tokenizer|KinoSearch::Analysis::Tokenizer>), or it
might convert text to lowercase
(L<LCNormalizer|KinoSearch::Analysis::LCNormalizer>).

=head1 SUBCLASSING

All Analyzer subclasses must provide an C<analyze> method.

=head2 analyze

C<analyze()> takes a single L<TokenBatch|KinoSearch::Analysis::TokenBatch> as
input, and it returns a TokenBatch, either the same one (presumably
transformed in some way), or a new one.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut

