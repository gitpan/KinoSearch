use strict;
use warnings;

package KinoSearch::Util::Hash;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        capacity => 16,
    );
}
our %instance_vars;

1;

__END__

__XS__

MODULE =  KinoSearch    PACKAGE = KinoSearch::Util::Hash

kino_Hash*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::Hash::instance_vars");
    kino_u32_t capacity = extract_uv(args_hash, SNL("capacity"));

    /* build object */
    RETVAL = kino_Hash_new(capacity);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_Hash *self;
ALIAS:
    get_size   = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH
    
    case 2:  retval = newSVuv(self->size);
             break;

    END_SET_OR_GET_SWITCH
}

void
store(self, key_sv, val)
    kino_Hash *self;
    SV *key_sv;
    kino_Obj *val;
PPCODE:
{
    STRLEN len;
    char *ptr = SvPV(key_sv, len);
    Kino_Hash_Store(self, ptr, len, val);
}

SV*
fetch(self, key)
    kino_Hash *self;
    kino_ByteBuf key;
CODE:
{
    kino_Obj *fetched = Kino_Hash_Fetch_BB(self, &key);

    if (fetched == NULL) {
        RETVAL = newSV(0);
    }
    else {
        RETVAL = kobj_to_pobj(fetched);
    }
}
OUTPUT: RETVAL

void
clear(self)
    kino_Hash *self;
PPCODE:
    Kino_Hash_Clear(self);

kino_bool_t
delete(self, key)
    kino_Hash *self;
    kino_ByteBuf key;
CODE:
    RETVAL = Kino_Hash_Delete_BB(self, &key);
OUTPUT: RETVAL

void
iter_init(self)
    kino_Hash *self;
PPCODE:
    Kino_Hash_Iter_Init(self);

void
iter_next(self)
    kino_Hash *self;
PPCODE:
{
    kino_ByteBuf *key;
    kino_Obj     *val;

    if (Kino_Hash_Iter_Next(self, &key, &val)) {
        SV *key_sv = kobj_to_pobj(key);
        SV *val_sv = kobj_to_pobj(val);

        XPUSHs(sv_2mortal( key_sv ));
        XPUSHs(sv_2mortal( val_sv ));
        XSRETURN(2);
    }
    else {
        XSRETURN_EMPTY;
    }
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::Hash - Hashtable.

=head1 DESCRIPTION

Private hashtable module for KinoSearch's internal use.  The keys are
ByteBufs; the values may belong to any subclass of Obj. The hashing function
is the one used by Perl 5.8.8: Bob Jenkin's "one-at-a-time" algorithm.
Collisions are resolved using a linked list.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

