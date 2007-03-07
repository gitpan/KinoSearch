use strict;
use warnings;

package KinoSearch::Index::Term;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN { __PACKAGE__->init_instance_vars() }

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::Term

kino_Term*
new(class_name, field, text)
    const classname_char *class_name;
    kino_ByteBuf_utf8 field;
    kino_ByteBuf_utf8 text;
CODE:
    KINO_UNUSED_VAR(class_name);
    RETVAL = kino_Term_new(&field, &text);
OUTPUT: RETVAL

kino_Term*
deserialize(either_sv, serialized)
    SV *either_sv;
    kino_ViewByteBuf serialized;
CODE:
    KINO_UNUSED_VAR(either_sv);
    RETVAL = kino_Term_deserialize(&serialized);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_Term *self;
ALIAS:
    set_field = 1
    get_field = 2
    set_text  = 3
    get_text  = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  {
                STRLEN len;
                char *ptr = SvPVutf8( ST(1), len );
                Kino_BB_Copy_Str(self->field, ptr, len);
             }
             break;

    case 2:  retval = bb_to_sv(self->field);
             SvUTF8_on(retval);
             break;

    case 3:  {
                STRLEN len;
                char *ptr = SvPVutf8( ST(1), len );
                Kino_BB_Copy_Str(self->text, ptr, len);
             }
             break;

    case 4:  retval = bb_to_sv(self->text);
             SvUTF8_on(retval);
             break;
    
    END_SET_OR_GET_SWITCH
}

__POD__

=head1 NAME

KinoSearch::Index::Term - String of text associated with a field.

=head1 SYNOPSIS

    my $foo_term   = KinoSearch::Index::Term->new( 'content', 'foo' );
    my $term_query = KinoSearch::Search::TermQuery->new( term => $foo_term );

=head1 DESCRIPTION

The Term is the unit of search.  It has two characteristics: a field name, and
term text.  

=head1 METHODS

=head2 new

    my $term = KinoSearch::Index::Term->new( FIELD_NAME, TERM_TEXT );

Constructor.

=head2 set_text get_text set_field get_field

Getters and setters.

=head2 to_string

Returns a string representation of the Term object.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut


