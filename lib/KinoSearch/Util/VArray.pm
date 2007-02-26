use strict;
use warnings;

package KinoSearch::Util::VArray;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        capacity => undef,
    );
}
our %instance_vars;

1;

__END__

__XS__

MODULE =  KinoSearch    PACKAGE = KinoSearch::Util::VArray

kino_VArray*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::VArray::instance_vars");
    kino_u32_t capacity = extract_uv(args_hash, SNL("capacity"));

    /* build object */
    RETVAL = kino_VA_new(capacity);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_VArray *self;
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
push(self, element)
    kino_VArray *self;
    kino_Obj    *element;
PPCODE:
    Kino_VA_Push(self, element);

SV*
pop(self)
    kino_VArray *self;
CODE:
{
    kino_Obj *obj = Kino_VA_Pop(self);
    if (obj == NULL) {
        RETVAL = newSV(0);
    }
    else {
        RETVAL = kobj_to_pobj(obj);
        REFCOUNT_DEC(obj);
    }
}
OUTPUT: RETVAL

void
unshift(self, element)
    kino_VArray *self;
    kino_Obj    *element;
PPCODE:
    Kino_VA_Unshift(self, element);

SV*
shift(self)
    kino_VArray *self;
CODE:
{
    kino_Obj *obj = Kino_VA_Shift(self);
    if (obj == NULL) {
        RETVAL = newSV(0);
    }
    else {
        RETVAL = kobj_to_pobj(obj);
        REFCOUNT_DEC(obj);
    }
}
OUTPUT: RETVAL

SV*
fetch(self, num)
    kino_VArray *self;
    kino_u32_t   num;
CODE:
{
    kino_Obj *obj = Kino_VA_Fetch(self, num);
    RETVAL = obj == NULL 
        ? newSV(0)
        : kobj_to_pobj(obj);
}
OUTPUT: RETVAL

void
store(self, num, elem)
    kino_VArray *self;
    kino_u32_t num;
    kino_Obj *elem;
PPCODE: 
    Kino_VA_Store(self, num, elem);
    
__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::VArray - Variable-sized array.

=head1 DESCRIPTION

KinoSearch needs a variable sized array for its own internal use --
essentially a lightweight version of Perl's AV.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

