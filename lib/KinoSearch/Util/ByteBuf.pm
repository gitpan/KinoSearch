use strict;
use warnings;

package KinoSearch::Util::ByteBuf;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj Exporter );

our @EXPORT_OK = qw( bb_compare bb_less_than );    # testing only

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::ByteBuf

kino_ByteBuf*
new(class, sv)
    const classname_char *class;
    SV *sv;
CODE:
{
    STRLEN len;
    char *ptr = SvPV(sv, len);
    RETVAL = kino_BB_new_str(ptr, len);
    CHY_UNUSED_VAR(class);
}
OUTPUT: RETVAL

chy_bool_t
starts_with(self, prefix)
    kino_ByteBuf *self;
    kino_ByteBuf *prefix;
CODE:
    RETVAL = Kino_BB_Starts_With(self, prefix);
OUTPUT: RETVAL

chy_bool_t
ends_with(self, postfix)
    kino_ByteBuf *self;
    kino_ByteBuf *postfix;
CODE:
    RETVAL = Kino_BB_Ends_With_Str(self, postfix->ptr, postfix->len);
OUTPUT: RETVAL

chy_i32_t
bb_compare(bb_a, bb_b)
    kino_ByteBuf *bb_a;
    kino_ByteBuf *bb_b;
CODE: 
    RETVAL = kino_BB_compare(&bb_a, &bb_b);
OUTPUT: RETVAL

chy_i32_t
bb_less_than(bb_a, bb_b)
    kino_ByteBuf *bb_a;
    kino_ByteBuf *bb_b;
CODE: 
    RETVAL = kino_BB_less_than(&bb_a, &bb_b);
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::ByteBuf - Lightweight scalar.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
