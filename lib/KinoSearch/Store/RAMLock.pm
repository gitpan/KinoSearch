package KinoSearch::Store::RAMLock;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Lock );

our %instance_vars = __PACKAGE__->init_instance_vars;

sub do_obtain {
    my $self = shift;

    # bail if the virtual lockfile already exists
    return if $self->{invindex}->file_exists( $self->{lock_name} );

    # create a virtual lockfile
    my $temp = $self->{invindex}->open_outstream( $self->{lock_name} );
    $temp->close;
    return 1;
}

sub release {
    my $self = shift;

    # delete the virtual lockfile
    $self->{invindex}->delete_file( $self->{lock_name} );
}

sub is_locked {
    my $self = shift;
    return $self->{invindex}->file_exists( $self->{lock_name} );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Store::RAMLock - lock a RAMInvIndex

=head1 DESCRIPTION

Implementation of KinoSearch::Store::Lock entirely in memory.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=end devdocs
=cut
