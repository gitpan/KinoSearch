use strict;
use warnings;

package KinoSearch::Util::Obj;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

sub deserialize { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::Obj

kino_Obj*
_new(class)
    const classname_char *class;
CODE:
    KINO_UNUSED_VAR(class);
    RETVAL = kino_Obj_new();
OUTPUT: RETVAL

kino_Obj*
clone(self)
    kino_Obj *self;
CODE:
    RETVAL = Kino_Obj_Clone(self);
OUTPUT: RETVAL

kino_bool_t
equals(self, other)
    kino_Obj *self;
    kino_Obj *other;
CODE:
    RETVAL = Kino_Obj_Equals(self, other);
OUTPUT: RETVAL

kino_i32_t
hash_code(self)
    kino_Obj *self;
CODE:
    RETVAL = Kino_Obj_Hash_Code(self);
OUTPUT: RETVAL

=for comment
Uses class names rather than VTABLE pointers from Perl space.

=cut

kino_bool_t
is_a(self, class_name)
    kino_Obj *self;
    const char *class_name;
CODE:
{
    const KINO_OBJ_VTABLE *vtable = self->_;

    RETVAL = FALSE;
    while (vtable != NULL) {
        if (strcmp(class_name, vtable->class_name) == 0) {
             RETVAL = TRUE;
             break;
        }
        vtable = vtable->parent;
    }
}
OUTPUT: RETVAL

SV*
to_string(self, ...)
    kino_Obj *self;
CODE:
{
    kino_ByteBuf *bb = Kino_Obj_To_String(self);
    RETVAL = bb_to_sv(bb);
    REFCOUNT_DEC(bb);
}
OUTPUT: RETVAL

SV*
serialize(self)
    kino_Obj *self;
CODE:
{
    kino_ByteBuf *serialized_bb = kino_BB_new(0);
    Kino_Obj_Serialize(self, serialized_bb);
    RETVAL = bb_to_sv(serialized_bb);
    REFCOUNT_DEC(serialized_bb);
}
OUTPUT: RETVAL

void
STORABLE_freeze(self, ...)
    kino_Obj *self;
PPCODE:
    if (items < 2 || !SvTRUE(ST(1))) {
        SV *retval;
        kino_ByteBuf *serialized_bb = kino_BB_new(0);
        Kino_Obj_Serialize(self, serialized_bb);
        retval = bb_to_sv(serialized_bb);
        REFCOUNT_DEC(serialized_bb);
        ST(0) = sv_2mortal(retval);
        XSRETURN(1);
    }

=begin comment

Calls deserialize(), and copies the object pointer.  Since deserialize is an
abstract method, it will confess() unless implemented.

=end comment
=cut

void
STORABLE_thaw(blank_obj, cloning, serialized_sv)
    SV *blank_obj;
    SV *cloning;
    SV *serialized_sv;
PPCODE:
{
    int count;
    SV *deserialized_pobj;
    kino_Obj *obj;
    SV *deep_obj = SvRV(blank_obj);
    KINO_UNUSED_VAR(cloning);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(blank_obj);
    PUSHs(serialized_sv);
    PUTBACK;

    count = call_method("deserialize", G_SCALAR);
    if (count != 1)
        CONFESS("Failed to return an scalar");

    deserialized_pobj = ST(0);

    obj = INT2PTR( kino_Obj*, SvIV(SvRV(deserialized_pobj)) );
    REFCOUNT_INC(obj);
    sv_setiv(deep_obj, PTR2IV(obj) );

    PUTBACK;
    FREETMPS;
    LEAVE;
}


SV*
to_perl(self)
    kino_Obj *self;
CODE:
    RETVAL = nat_obj_to_pobj(self);
OUTPUT: RETVAL

void
DESTROY(self)
    kino_Obj *self;
PPCODE:
    /*
    {
        char *perl_class = HvNAME(SvSTASH(SvRV(ST(0))));
        warn("Destroying: 0x%x %s", (unsigned)self, perl_class);
    }
    */
    REFCOUNT_DEC(self);

=for comment

These three are for testing purposes only.

=cut

UV
refcount(self)
    kino_Obj *self;
CODE:
    RETVAL = self->refcount;
OUTPUT: RETVAL

void
refcount_inc(self);
    kino_Obj *self;
PPCODE:
    REFCOUNT_INC(self);

void
refcount_dec(self);
    kino_Obj *self;
PPCODE:
    REFCOUNT_DEC(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::Obj - Base class for C-struct objects.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
