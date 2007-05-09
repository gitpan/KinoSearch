use strict;
use warnings;

package MemberVar;
use Carp;

sub new {
    my $either     = shift;
    my $perl_class = ref($either) || $either;
    my $self       = bless {
        type => undef,
        name => undef,
        @_,
    }, $perl_class;
    return $self;
}

sub get_type { shift->{type} }
sub get_name { shift->{name} }

1;

