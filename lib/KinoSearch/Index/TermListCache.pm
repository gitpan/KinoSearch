use strict;
use warnings;

package KinoSearch::Index::TermListCache;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermList );

BEGIN {
    __PACKAGE__->init_instance_vars();
}

# No constructor needed.  Just the base class, so that inherited perl methods
# work (e.g. DESTROY).

1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermListCache - Cache a TermList in RAM

=head1 DESCRIPTION

Loads a TermList into RAM.  Used to hold index term lists, either read in from
disk or created on the fly.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

