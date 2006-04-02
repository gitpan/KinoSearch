package KinoSearch::Util::ToolSet;
use strict;
use warnings;
use bytes;
no bytes;

use base qw( Exporter );

use Carp qw( carp croak cluck confess );
# everything except readonly and set_prototype
use Scalar::Util qw(
    refaddr
    blessed
    dualvar
    isweak
    refaddr
    reftype
    tainted
    weaken
    isvstring
    looks_like_number
);
use KinoSearch qw( K_DEBUG kdump );
use KinoSearch::Util::VerifyArgs qw( verify_args a_isa_b );
use KinoSearch::Util::MathUtils qw( ceil );

our @EXPORT = qw(
    carp
    croak
    cluck
    confess

    refaddr
    blessed
    dualvar
    isweak
    refaddr
    reftype
    tainted
    weaken
    isvstring
    looks_like_number

    K_DEBUG
    kdump

    verify_args
    a_isa_b

    ceil
);

1;

__END__

=head1 NAME

KinoSearch::Util::ToolSet - namespace pollution

=head1 PRIVATE CLASS

This is a private class and the interface may change radically and without
warning.  Do not use it on its own.

=head1 SYNOPSIS

    use KinoSearch::Util::ToolSet;

=head1 DESCRIPTION

KinoSearch::Util::ToolSet makes a slew of commonly needed symbols available to
other modules in the KinoSearch suite.  At one time it was implemented using
David Golden's L<ToolSet|ToolSet> module, but in keeping with the philosophy
of minimizing non-core dependencies, a 90% solution based on Exporter has been
substituted.

    use KinoSearch::Util::ToolSet;

... is effectively an alias for...

    use bytes; no bytes;
    use Carp qw( carp croak cluck confess );
    use Scalar::Util qw( 
                         refaddr
                         blessed 
                         dualvar 
                         isweak 
                         refaddr 
                         reftype 
                         tainted 
                         weaken 
                         isvstring 
                         looks_like_number 
                         );
    use KinoSearch qw( K_DEBUG kdump );
    use KinoSearch::Util::VerifyArgs qw( verify_args a_isa_b );
    use KinoSearch::Util::MathUtils qw( ceil );

Two issues deserve special attention.

First, the C<use bytes; no bytes;> combo ensures that subroutines within the
bytes:: namespace, such as bytes::length, will be available, while still
keeping character semantics enabled by default -- so regexes work as expected,
etc.

Second, the C<use KinoSearch> line does a LOT more than it appears to at
first glance -- it loads ALL of the XS routines in the entire KinoSearch
suite.  See L<KinoSearch::Docs::DevGuide|KinoSearch::Docs::DevGuide> for an
explanation.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=cut
