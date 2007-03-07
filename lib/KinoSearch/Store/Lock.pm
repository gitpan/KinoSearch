use strict;
use warnings;

package KinoSearch::Store::Lock;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        folder    => undef,
        lock_name => undef,
        lock_id   => "",
        timeout   => 0,
    );
}
our %instance_vars;

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
    kino_i32_t timeout     = extract_iv(args_hash, SNL("timeout"));
    SV *lock_name_sv       = extract_sv(args_hash, SNL("lock_name"));
    SV *lock_id_sv         = extract_sv(args_hash, SNL("lock_id"));
    kino_ByteBuf lock_name = KINO_BYTEBUF_BLANK;
    kino_ByteBuf lock_id   = KINO_BYTEBUF_BLANK;
    SV_TO_TEMP_BB(lock_name_sv, lock_name);
    SV_TO_TEMP_BB(lock_id_sv, lock_id);

    /* create object */
    RETVAL = kino_Lock_new(folder, &lock_name, &lock_id, timeout);
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

IV
is_locked(self);
    kino_Lock *self;
CODE:
    RETVAL = Kino_Lock_Is_Locked(self);
OUTPUT: RETVAL
    
void
_set_or_get(self, ...)
    kino_Lock *self;
ALIAS:
    get_lock_name = 2
    get_lock_id   = 4
    get_folder    = 6
    get_timeout   = 8
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = bb_to_sv(self->lock_name);
             break;

    case 4:  retval = bb_to_sv(self->lock_id);
             break;

    case 6:  retval = kobj_to_pobj(self->folder);
             break;

    case 8:  retval = newSViv(self->timeout);
             break;

    END_SET_OR_GET_SWITCH
}


__POD__


=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::Lock - Mutex lock on a Folder.

=head1 SYNOPSIS

    my $lock = $folder->make_lock(
        lock_name => WRITE_LOCK_NAME,
        lock_id   => $hostname,
        timeout   => 5000,
    );

=head1 DESCRIPTION

The Lock class produces an interprocess mutex lock.  It does not rely on
flock, but creates a lock "file".  What exactly constitutes that "file"
depends on the Folder implementation.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


