use strict;
use warnings;

package KinoSearch::Store::Lock;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # params / members
    folder    => undef,
    lock_name => undef,
    agent_id  => undef,
    timeout   => 0,
);

=begin comment

    $lock->run_while_locked(
        do_body   => \&do_some_stuff,
    );

Obtain a lock, run the subroutine specified by the do_body parameter, then
release the lock.

=end comment
=cut

sub run_while_locked {
    my ( $self, %args ) = @_;
    my $do_body = delete $args{do_body};
    my $locked;
    eval {
        $locked = $self->obtain;
        confess("Failed to obtain lock") unless $locked;
        $do_body->();
    };
    my $saved_error = $@;
    $self->release        if $self->is_locked;
    confess($saved_error) if $saved_error;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::Lock

kino_Lock*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::Lock::instance_vars");
    kino_Folder *folder = (kino_Folder*)extract_obj(args_hash,
        SNL("folder"), "KinoSearch::Store::Folder");
    chy_i32_t timeout      = extract_iv(args_hash, SNL("timeout"));
    SV *lock_name_sv       = extract_sv(args_hash, SNL("lock_name"));
    SV *agent_id_sv        = extract_sv(args_hash, SNL("agent_id"));
    kino_ByteBuf lock_name = KINO_BYTEBUF_BLANK;
    kino_ByteBuf agent_id  = KINO_BYTEBUF_BLANK;
    SV_TO_TEMP_BB(lock_name_sv, lock_name);
    SV_TO_TEMP_BB(agent_id_sv, agent_id);

    /* create object */
    RETVAL = kino_Lock_new(folder, &lock_name, &agent_id, timeout);
}
OUTPUT: RETVAL

IV
obtain(self);
    kino_Lock *self;
CODE:
    RETVAL = Kino_Lock_Obtain(self);
OUTPUT: RETVAL
    
IV
do_obtain(self);
    kino_Lock *self;
CODE:
    RETVAL = Kino_Lock_Do_Obtain(self);
OUTPUT: RETVAL

void
release(self);
    kino_Lock *self;
PPCODE:
    Kino_Lock_Release(self);

chy_bool_t
is_locked(self);
    kino_Lock *self;
CODE:
    RETVAL = Kino_Lock_Is_Locked(self);
OUTPUT: RETVAL

void
clear_stale(self);
    kino_Lock *self;
PPCODE:
    Kino_Lock_Clear_Stale(self);
    
void
_set_or_get(self, ...)
    kino_Lock *self;
ALIAS:
    get_lock_name = 2
    get_agent_id  = 4
    get_folder    = 6
    get_timeout   = 8
    get_filename  = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = bb_to_sv(self->lock_name);
             break;

    case 4:  retval = bb_to_sv(self->agent_id);
             break;

    case 6:  retval = kobj_to_pobj(self->folder);
             break;

    case 8:  retval = newSViv(self->timeout);
             break;

    case 10: retval = self->filename == NULL 
                        ? newSV(0)
                        : bb_to_sv(self->filename);
             break;

    END_SET_OR_GET_SWITCH
}


__POD__

=head1 NAME 

KinoSearch::Store::Lock - Interprocess mutex lock.

=head1 SYNOPSIS

    my $lock = $lock_factory->make_lock(
        lock_name => 'commit',
        timeout   => 5000,
    );
    $lock->obtain or die "can't get lock on " . $lock->get_filename;
    do_stuff();
    $lock->release;

=head1 DESCRIPTION

The Lock class produces an interprocess mutex lock, using a lock "file".  What
exactly constitutes that "file" depends on the
L<Folder|KinoSearch::Store::Folder> implementation.

Each lock must have a name which is unique per resource to be locked.  The
filename for the lockfile will be derived from it, e.g. "write" will generate
the file "write.lock".

Each lock also has an "agent id", a string which should be unique per-host; it
is used to help clear away stale lockfiles.

=head1 CONSTRUCTOR 

    my $lock = KinoSearch::Store::Lock->new(
        lock_name => 'commit',           # required
        timeout   => 5000,               # default: 0
        folder    => $folder,            # required
        agent_id  => $hostname,          # required
    );

Create a Lock.  Takes named parameters.

=over

=item *

B<lock_name> - String identifying the resource to be locked.

=item *

B<timeout> - Time in I<milliseconds> to keep retrying before abandoning the
attempt to obtain() a lock.

=item *

B<folder> - An object which isa L<KinoSearch::Store::Folder>.

=item *

B<agent_id> - An identifying string, usually the host name.

=back

=head1 METHODS

=head2 obtain

    $lock->obtain or die "Couldn't get lock";

Attempt to aquire lock once per second until the timeout has been reached.
Returns true upon success, false otherwise.

=head2 release

    $lock->release;

Release the lock.

=head2 is_locked

    do_stuff() if $lock->is_locked;

Returns a boolean indicating whether the resource identified by this lock's
lock_name string is currently locked.

=head2 clear_stale

    $lock->clear_stale;
    $lock->obtain or die "Can't get lock";

Release all locks that meet the following criteria:

=over

=item 1

C<lock_name> matches.

=item 2

C<agent_id> matches.

=item 3

The process id that the lock was created under no longer identifies an active
process.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
