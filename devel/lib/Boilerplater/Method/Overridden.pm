package Boilerplater::Method::Overridden;
use Carp;
use base qw( Boilerplater::Method );
use Boilerplater qw( $prefix $Prefix $PREFIX );

sub new { confess "Objects can only be reblessed into " . __PACKAGE__ }

sub set_orig {
    my ( $self, $orig ) = @_;
    $self->{orig} = $orig;
}

# The typedefs for an overridden method are those of its oldest ancestor.
# This is done because the members of the vtable struct must match those of
# the parent vtable or we'll get compiler warnings.
sub typedef       { shift->{orig}->typedef }
sub short_typedef { shift->{orig}->short_typedef }

# Create a method macro, using this class's nick, but inheriting everything
# else.
sub macro_def {
    my ( $self, $invoker ) = @_;
    confess("cant find ancestor for $self->{class_nick} $self->{micro_name}")
        unless defined $self->{orig};
    return $self->{orig}->macro_def($invoker);
}

1;
