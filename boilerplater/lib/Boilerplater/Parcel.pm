use strict;
use warnings;

package Boilerplater::Parcel;
use base qw( Exporter );
use Boilerplater::Util qw( verify_args );
use Carp;

our %parcels;

our %singleton_PARAMS = (
    name  => undef,
    cnick => undef,
);

# Create the default parcel.
our $default_parcel = __PACKAGE__->singleton(
    name  => 'DEFAULT',
    cnick => '',
);

sub default_parcel {$default_parcel}

sub singleton {
    my ( $either, %args ) = @_;
    verify_args( \%singleton_PARAMS, %args ) or confess $@;
    my ( $name, $cnick ) = @args{qw( name cnick )};

    # Return the default parcel for either a blank name or an undefined name.
    return $default_parcel unless $name;

    # Return an existing singleton if the parcel has already been registered.
    my $existing = $parcels{$name};
    if ($existing) {
        if ( $cnick and $cnick ne $existing->{cnick} ) {
            confess(  "cnick '$cnick' for parcel '$name' conflicts with "
                    . "'$existing->{cnick}'" );
        }
        return $existing;
    }

    # Register new parcel.  Default cnick to name.
    my $self = bless { %singleton_PARAMS, %args, }, ref($either) || $either;
    defined $self->{cnick} or $self->{cnick} = $self->{name};
    $parcels{$name} = $self;

    # Pre-generate prefixes.
    $self->{Prefix} = length $self->{cnick} ? "$self->{cnick}_" : "";
    $self->{prefix} = lc( $self->{Prefix} );
    $self->{PREFIX} = uc( $self->{Prefix} );

    return $self;
}

# Accessors.
sub get_prefix { shift->{prefix} }
sub get_Prefix { shift->{Prefix} }
sub get_PREFIX { shift->{PREFIX} }

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $self->{name}  eq $other->{name};
    return 0 unless $self->{cnick} eq $other->{cnick};
    return 1;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Parcel - Collection of code.

=head1 DESCRIPTION

A Parcel is a cohesive collection of code, which could, in theory, be
published as as a single entity.

Boilerplater supports two-tier manual namespacing, using a prefix, an optional
class nickname, and the local symbol:

  prefix_ClassNick_local_symbol
  
Boilerplater::Parcel supports the first tier, specifying initial prefixes.
These prefixes come in three capitalization variants: prefix_, Prefix_, and
PREFIX_.

=head1 CLASS METHODS

=head2 singleton 

    Boilerplater::Parcel->singleton(
        name  => 'Crustacean',
        cnick => 'Crust',
    );

Add a Parcel singleton to a global registry.  May be called multiple times,
but only with compatible arguments.

=over

=item *

B<name> - The name of the parcel.

=item *

B<cnick> - The C nickname for the parcel, which will be used as a prefix for
generated global symbols.  Must be mixed case and start with a capital letter.
Defaults to C<name>.

=back

=head2 default_parcel

   $parcel ||= Boilerplater::Parcel->default_parcel;

Return the singleton for default parcel, which has no prefix.

=head1 OBJECT METHODS

=head2 get_prefix get_Prefix get_PREFIX

Return one of the three capitalization variants for the parcel's prefix.

=head1 COPYRIGHT

Copyright 2006-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
