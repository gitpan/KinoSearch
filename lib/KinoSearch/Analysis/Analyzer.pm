package KinoSearch::Analysis::Analyzer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        language => '',
    );
}

# usage: $token_batch = $analyzer->analyze($token_batch);
sub analyze { return $_[1] }

1;

__END__

=head1 NAME

KinoSearch::Analysis::Analyzer - base class for analyzers

=head1 SYNOPSIS

    # abstract base class -- you probably want PolyAnalyzer, not this.

=head1 DESCRIPTION

In KinoSearch, an Analyzer is a filter which processes text, transforming it
from one form into another.  For instance, an analyzer might break up a long
text into smaller pieces (L<Tokenizer|KinoSearch::Analysis::Tokenizer>), or it
might convert text to lowercase
(L<LCNormalizer|KinoSearch::Analysis::LCNormalizer>).

=head1 METHODS

=head2 analyze (EXPERIMENTAL)

    $token_batch = $analyzer->analyze($token_batch);

All Analyzer subclasses provide an C<analyze> method.  C<analyze()>
takes a single L<TokenBatch|KinoSearch::Analysis::TokenBatch> as input, and it
returns a TokenBatch, either the same one (probably transformed in some way),
or a new one.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.15.

=cut

