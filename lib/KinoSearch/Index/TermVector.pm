use strict;
use warnings;

package KinoSearch::Index::TermVector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # params / members
    field         => undef,
    text          => undef,
    positions     => [],
    start_offsets => [],
    end_offsets   => [],
);

BEGIN {
    __PACKAGE__->ready_get_set(
        qw(
            field
            text
            positions
            start_offsets
            end_offsets
            )
    );
}

1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermVector - Term freq and positional data.

=head1 DESCRIPTION

Ancillary information about a Term.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


