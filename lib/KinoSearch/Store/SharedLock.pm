use strict;
use warnings;

package KinoSearch::Store::SharedLock;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Lock );

our %instance_vars = (
    # inherited
    folder    => undef,
    lock_name => undef,
    agent_id  => undef,
    timeout   => 0,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::SharedLock

kino_SharedLock*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::SharedLock::instance_vars");
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
    RETVAL = kino_ShLock_new(folder, &lock_name, &agent_id, timeout);
}
OUTPUT: RETVAL


__POD__

=head1 NAME

KinoSearch::Store::SharedLock - Shared (read) lock.

=head1 SYNOPSIS

    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $folder,
        agent_id  => $hostname,
    );
    my $lock = $lock_factory->make_shared_lock(
        lock_name => 'segments_6r',
        timeout   => 5000,
    );

=head1 DESCRIPTION

SharedLock's interface is nearly identical to that of its parent class
L<KinoSearch::Store::Lock>, taking the same constructor arguments and
implementing the same list of methods.  It differs from Lock only in the
semantics of two methods:

=over

=item *

obtain() will not fail if another lock is held against C<lock_name> (though it
might fail for other reasons).

=item *

is_locked() returns true so long as some lock, somewhere is holding a lock on
the resource identified by C<lock_name>.  That lock could be this instance, or
it could be another.  So this sequence is entirely possible:

    $lock->release; # works this time
    $lock->release; # doesn't do anything
    print "Still locked!" if $lock->is_locked; # prints "Still locked!"

=back

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut


