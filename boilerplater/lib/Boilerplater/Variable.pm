use strict;
use warnings;

package Boilerplater::Variable;
use base qw( Boilerplater::Symbol );
use Boilerplater::Type;
use Boilerplater::Util qw( verify_args );
use Carp;

our %new_PARAMS = (
    type      => undef,
    micro_sym => undef,
    parcel    => undef,
    exposure  => 'local',
);

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    my $self = $either->SUPER::new( %new_PARAMS, @_ );
    confess "micro_sym is required" unless $self->{micro_sym};
    confess "invalid type"
        unless ref( $self->{type} )
            && $self->{type}->isa("Boilerplater::Type");
    return $self;
}

sub get_type  { shift->{type} }
sub micro_sym { shift->{micro_sym} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{micro_sym} eq $other->{micro_sym};
    return 0 unless $self->{type}->equals( $other->{type} );
    return $self->SUPER::equals($other);
}

sub to_c {
    my $self      = shift;
    my $type      = $self->{type};
    my $array_str = $type->get_array || "";
    my $type_str  = $array_str ? $type->to_c : $type->to_c;
    return "$type_str $self->{micro_sym}$array_str";
}

sub c_declaration { return shift->to_c . ';' }

1;

__END__

__POD__

=head1 NAME

Boilerplater::Variable - A Boilerplater variable.

=head1 DESCRIPTION

A variable, having a Type, a micro_sym (i.e. name), and an ACL.

=head1 METHODS

=head2 new

    my $var = Boilerplater::Variable->new(
        type      => $type,    # required
        micro_sym => 'foo',    # required
        exposure  => undef,    # default: 'local'
    );

=over

=item *

B<type> - A Boilerplater::Type. 

=item *

B<micro_sym> - The variable's name, without any namespacing prefixes.

=item *

B<exposure> - The scope at which the variable is exposed.  Must be 'public',
'parcel', 'private', or 'local'.

=back

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut


