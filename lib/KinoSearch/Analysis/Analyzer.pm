package KinoSearch::Analysis::Analyzer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars( language => '', );

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
text into an array of tokens, or it might convert text to lowercase.

=head1 TODO

At this time, public subclassing of Analyzer is not supported.  If that is to
happen, the problem of how to store a collection of tokens both efficiently
and elegantly must be solved.  An array of tokens, each of which is a
hash-based object, is elegant but not efficient.  The current scheme is
efficient but not elegant.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=cut
