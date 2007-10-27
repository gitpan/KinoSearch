use strict;
use warnings;

package KinoSearch::Store::LockFactory;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # params
    folder   => undef,
    agent_id => undef,
);

use KinoSearch::Store::Lock;
use KinoSearch::Store::SharedLock;

our %make_lock_vars = (
    lock_name => undef,
    timeout   => undef,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::LockFactory

kino_LockFactory*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::LockFactory::instance_vars");
    kino_Folder *folder = (kino_Folder*)extract_obj(args_hash,
        SNL("folder"), "KinoSearch::Store::Folder");
    SV *agent_id_sv        = extract_sv(args_hash, SNL("agent_id"));
    kino_ByteBuf agent_id  = KINO_BYTEBUF_BLANK;
    if (!SvOK(agent_id_sv))
        CONFESS("missing required parameter 'agent_id'");
    SV_TO_TEMP_BB(agent_id_sv, agent_id);

    /* create object */
    RETVAL = kino_LockFact_new(folder, &agent_id);
}
OUTPUT: RETVAL

kino_Lock*
_create_a_lock(self, ...);
    kino_LockFactory *self;
ALIAS:
    make_lock        = 1
    make_shared_lock = 2
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::LockFactory::make_lock_vars");
    chy_i32_t timeout       = extract_iv(args_hash, SNL("timeout"));
    SV *lock_name_sv        = extract_sv(args_hash, SNL("lock_name"));
    kino_ByteBuf lock_name  = KINO_BYTEBUF_BLANK;
    if (!SvOK(lock_name_sv))
        CONFESS("missing required parameter 'lock_name'");
    SV_TO_TEMP_BB(lock_name_sv, lock_name);

    /* create object */
    if (ix == 1) {
        RETVAL = Kino_LockFact_Make_Lock(self, &lock_name, timeout);
    }
    else {
        RETVAL = (kino_Lock*)Kino_LockFact_Make_Shared_Lock(self, 
            &lock_name, timeout); 
    }
}
OUTPUT: RETVAL


__POD__

=head1 NAME

KinoSearch::Store::LockFactory - Create Locks.

=head1 SYNOPSIS

    use Sys::Hostname;
    my $hostname = hostname();
    die "Can't get unique hostname" unless $hostname;

    my $invindex = MySchema->open('/path/to/invindex/on/nfs/volume');
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $invindex->get_folder,
        agent_id  => $hostname,
    );
    my $index_reader = KinoSearch::Index::IndexReader->open(
        invindex     => $invindex,
        lock_factory => $lock_factory,
    );

=head1 DESRIPTION

Normally, LockFactory is an internal class, quietly doing its work behind the
scenes.  On shared volumes, however, the locking mechanism fails, and manual
intervention becomes necessary.

Both reading and writing applications accessing an index on a shared volume
need to identify themselves with an C<agent_id>, typically the hostname.
Knowing the hostname makes it possible to tell which lockfiles belong to other
machines and therefore must not be zapped when their pid can't be found.

=head2 Subclassing

LockFactory spins off L<Lock|KinoSearch::Store::Lock> and
L<SharedLock|KinoSearch::Store::SharedLock> objects at the request of other
KinoSearch classes.  If the behavior of Lock and SharedLock do not suit your
needs, you may substitute a custom subclass of LockFactory which spins off
your own Lock subclasses.

=head1 CONSTRUCTOR

    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $folder,    # required
        agent_id  => $hostname,  # required
    );

Create a LockFactory.  Takes named parameters.

=over

=item *

B<folder> - A L<KinoSearch::Store::Folder>.

=item *

B<agent_id> - An identifying string -- typically, the hostname.

=back

=head1 METHODS

=head2 make_lock 

    my $exclusive_lock = $lock_factory->make_lock(
        lock_name => 'foo',
        timeout   => 5000,
    );

Returns an exclusive lock on a resource.  Called with two hash-style
parameters, C<lock_name> and C<timeout>, which are passed on to Lock's
constructor. 

=head2 make_shared_lock 

    my $shared_lock = $lock_factory->make_lock(
        lock_name => 'foo',
        timeout   => 5000,
    );

Returns a shared lock on a resource.  Called with two hash-style parameters,
C<lock_name> and C<timeout>, which are passed on to SharedLock's constructor. 

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut


