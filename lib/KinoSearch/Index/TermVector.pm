package KinoSearch::Index::TermVector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # params / members
    field         => undef,
    text          => undef,
    positions     => [],
    start_offsets => [],
    end_offsets   => [],
);

__PACKAGE__->ready_get_set(
    qw( field text positions start_offsets end_offsets ));

1;

__END__

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::TermVector 

=head1 DESCRIPTION

=head1 METHODS

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut


