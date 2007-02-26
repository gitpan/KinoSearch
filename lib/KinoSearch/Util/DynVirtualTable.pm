use strict;
use warnings;

package KinoSearch::Util::DynVirtualTable;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars();
}

1;

__END__

__XS__

MODULE = KinoSearch PACKAGE = KinoSearch::Util::DynVirtualTable

=for comment

Testing only

=cut

kino_Hash*
_subclass_hash(class)
    const classname_char *class;
CODE:
{
    RETVAL    = kino_Hash_new(0);
    RETVAL->_ = (KINO_HASH_VTABLE*)kino_DynVT_singleton(class, 
        (KINO_OBJ_VTABLE*)&KINO_HASH, sizeof(KINO_HASH));
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::DynVirtualTable - Dynamic VTables for KinoSearch C objects.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
