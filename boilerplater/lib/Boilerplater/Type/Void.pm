use strict;
use warnings;

package Boilerplater::Type::Void;
use base qw( Boilerplater::Type );
use Boilerplater::Util qw( verify_args );
use Carp;

our %new_PARAMS = ( specifier => 'void', );

sub new {
    my $either = shift;
    verify_args( \%new_PARAMS, @_ ) or confess $@;
    return bless { %new_PARAMS, @_ }, ref($either) || $either;
}

# Accessors.
sub get_specifier { shift->{specifier} }
sub const         {0}
sub is_object     {0}
sub is_integer    {0}
sub is_floating   {0}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $other->isa(__PACKAGE__);
    return 1;
}

sub to_c {'void'}

1;

__END__

