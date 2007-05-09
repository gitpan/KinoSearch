use strict;
use warnings;

package KinoSearch::Analysis::Analyzer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    language => '',
);

use KinoSearch::Analysis::TokenBatch;

sub analyze_field {
    my ( $self, $doc, $field_name ) = @_;
    my $batch
        = KinoSearch::Analysis::TokenBatch->new( text => $doc->{$field_name},
        );
    return $self->analyze_batch($batch);
}

# Kick off an analysis chain, creating a TokenBatch.  Occasionally optimized
# to minimize string copies.
sub analyze_text {
    my $batch = KinoSearch::Analysis::TokenBatch->new( text => $_[1] );
    return $_[0]->analyze_batch($batch);
}

# Must override in a subclass
sub analyze_batch { shift->abstract_death }

# Convenience method which takes text as input and returns a Perl array of
# token texts.
sub analyze_raw {
    my $batch = $_[0]->analyze_text( $_[1] );
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

    sub analyze_batch {
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

All Analyzer subclasses must provide an C<analyze_batch> method.

=head2 analyze_batch

     $token_batch = $analyzer->analyze_batch($token_batch);

Abstract method. C<analyze_batch()> takes a single
L<TokenBatch|KinoSearch::Analysis::TokenBatch> as input, and it returns a
TokenBatch, either the same one (presumably transformed in some way), or a new
one.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
