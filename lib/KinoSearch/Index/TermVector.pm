package KinoSearch::Index::TermVector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # params / members
        field         => undef,
        text          => undef,
        positions     => [],
        start_offsets => [],
        end_offsets   => [],
    );
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

=head1 NAME

KinoSearch::Index::TermVector - Term freq and positional data  

=head1 DESCRIPTION

Ancillary information about a Term.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.12.

=end devdocs
=cut


