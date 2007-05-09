use strict;
use warnings;

package KinoSearch::Search::BooleanClause;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # params / members
    occur => 'SHOULD',
    query => undef,
);

sub init_instance {
    my $self = shift;

    confess("invalid value for 'occur': '$self->{occur}'")
        unless $self->{occur} =~ /^(?:MUST|MUST_NOT|SHOULD)$/;
}

__PACKAGE__->ready_get_set(qw( occur query ));

sub is_required   { shift->{occur} eq 'MUST' }
sub is_prohibited { shift->{occur} eq 'MUST_NOT' }

my %string_representations = (
    MUST     => '+',
    MUST_NOT => '-',
    SHOULD   => '',
);

sub to_string {
    my $self   = shift;
    my $string = $string_representations{"$self->{occur}"}
        . $self->{query}->to_string;
    return $string;
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::BooleanClause - Clause in a BooleanQuery.

=head1 DESCRIPTION 

A clause in a BooleanQuery.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

