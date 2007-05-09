use strict;
use warnings;

package KinoSearch::Util::IntMap;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    ints => undef
);

1;

__END__

__XS__

MODULE = KinoSearch PACKAGE = KinoSearch::Util::IntMap

kino_IntMap*
new(class, ...)
    const classname_char *class;
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::IntMap::instance_vars");
    SV *map_sv = extract_sv(args_hash, SNL("ints"));
    STRLEN len;
    char *map_ptr   = SvPV(map_sv, len);
    chy_i32_t size  = len / sizeof(chy_i32_t); 
    chy_i32_t *ints = KINO_MALLOCATE(size, chy_i32_t);

    /* dupe the map, since we can't steal the SV's pv allocation. */
    memcpy(ints, map_ptr, size * sizeof(chy_i32_t));

    /* build object */
    CHY_UNUSED_VAR(class);
    RETVAL = kino_IntMap_new(ints, size);
}
OUTPUT: RETVAL

=for comment

Return either the remapped number, or undef if the number is negative (as
would be the case if the index is out of range).

=cut

SV *
get(self, num)
    kino_IntMap *self;
    chy_i32_t    num;
CODE:
{
    chy_i32_t result = Kino_IntMap_Get(self, num);
    RETVAL = result == -1 ? newSV(0) : newSViv(result);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_IntMap *self;
ALIAS:
    get_size   = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH
    
    case 2:  retval = newSVuv(self->size);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::IntMap - Compact array of integers.

=head1 DESCRIPTION

An IntMap is a C array of i32_t, stored in a scalar.  

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
