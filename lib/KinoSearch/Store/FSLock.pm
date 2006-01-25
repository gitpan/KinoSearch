package KinoSearch::Store::FSLock;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Lock );

use Fcntl qw( :DEFAULT :flock );
use File::Spec::Functions qw( catfile );
use KinoSearch::Store::FSInvIndex;

my $disable_locks = 0;    # placeholder -- locks always enabled for now

our %instance_vars = __PACKAGE__->init_instance_vars();

sub init_instance {
    my $self = shift;

    # derive the lockfile's filepath
    $self->{lock_name} = catfile(
        $KinoSearch::Store::FSInvIndex::LOCK_DIR,  # TODO fix this stupid hack
        $self->{invindex}->get_lock_prefix . "-$self->{lock_name}"
    );
}

sub do_obtain {
    my $self = shift;

    return 1 if $disable_locks;

    # create a lock by creating a lockfile
    return
        unless
        sysopen( my $fh, $self->{lock_name}, O_CREAT | O_WRONLY | O_EXCL );
    CORE::close $fh or die "couldn't close '$self->{lock_name}': $!";
    return 1;
}

sub release {
    my $self = shift;

    return if $disable_locks;

    # release the lock by removing the lockfile from the file system
    unlink $self->{lock_name}
        or croak("Couldn't unlink file '$self->{lock_name}': $!");
}

sub is_locked {
    # if the lockfile exists, the resource is locked
    return ( -e $_[0]->{lock_name} or $disable_locks );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Store::FSLock - lock an FSInvIndex

=head1 DESCRIPTION

File-system-based implementation of
L<KinoSearch::Store::Lock|KinoSearch::Store::Lock>.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05.

=end devdocs
=cut

