use strict;
use warnings;

package KinoSearch::Analysis::Token;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        text         => undef,
        start_offset => undef,
        end_offset   => undef,
        boost        => 1.0,
        pos_inc      => 1,
    );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Analysis::Token

kino_Token*
new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Analysis::Token::instance_vars");
    SV *text_sv = extract_sv(args_hash, SNL("text"));
    STRLEN len;
    char *text = SvPVutf8(text_sv, len);
    kino_u32_t start   = extract_uv(args_hash, SNL("start_offset"));
    kino_u32_t end     = extract_uv(args_hash, SNL("end_offset"));
    float boost        = extract_nv(args_hash, SNL("boost"));
    kino_i32_t pos_inc = extract_iv(args_hash, SNL("pos_inc"));

    RETVAL = kino_Token_new(text, len, start, end, boost, pos_inc);
}
OUTPUT: RETVAL
    
void
_set_or_get(self, ...)
    kino_Token *self;
ALIAS:
    set_text         = 1
    get_text         = 2
    set_start_offset = 3
    get_start_offset = 4
    set_end_offset   = 5
    get_end_offset   = 6
    set_boost        = 7
    get_boost        = 8 
    set_pos_inc      = 9
    get_pos_inc      = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  free(self->text);
             {
                 STRLEN len;
                 char *str = SvPVutf8( ST(1), len);
                 self->text = kino_StrHelp_strndup(str, len);
                 self->len = len;
             }

    case 2:  retval = newSVpvn(self->text, self->len);
             SvUTF8_on(retval);
             break;

    case 3:  self->start_offset = SvUV( ST(1) );
             break;

    case 4:  retval = newSVuv(self->start_offset);
             break;

    case 5:  self->end_offset = SvUV( ST(1) );
             break;

    case 6:  retval = newSVuv(self->end_offset);
             break;

    case 7:  self->boost = SvNV( ST(1) );
             break;

    case 8:  retval = newSVnv(self->boost);
             break;

    case 9:  self->pos_inc = SvIV( ST(1) );
             break;

    case 10: retval = newSViv(self->pos_inc);
             break;
    
    END_SET_OR_GET_SWITCH
}


__POD__

=head1 NAME

KinoSearch::Analysis::Token - Unit of text.

=head1 SYNOPSIS

    my $token = KinoSearch::Analysis::Token->new(
        text         => 'horses',
        start_offset => 0,
        end_offset   => 6,
    );
    $token->set_text('hors');

=head1 DESCRIPTION

Token is the fundamental unit used by KinoSearch's Analyzer subclasses.  Each
Token has 5 attributes: 

=over 

=item *

B<text> - a UTF-8 string.

=item *

B<start_offset> - The start point of the token text, measured in UTF-8
characters from the top of the stored field. C<start_offset> and C<end_offset>
locate the Token within a larger context, even if the Token's text attribute
gets modified -- by stemming, for instance.  The Token for "beating" in the
text "beating a dead horse" begins life with a start_offset of 0 and an
end_offset of 7; after stemming, the text is "beat", but the start_offset is
still 0 and the end_offset is still 7.  This allows "beating" to be
highlighted correctly after a search matches "beat".

=item *

B<end_offset> The end of the token text, measured in UTF-8 characters from the
top of the field.

=item *

B<boost> - a per-token weight.  Use this when you want to assign more or less
importance to a particular token, as you might for emboldened text within an
HTML document, for example.  (Note: The field this token belongs to must be
spec'd to C<store_pos_boost>.)

=item *

B<pos_inc> - POSition INCrement, measured in Tokens.  This attribute, which
defaults to 1, is a an advanced tool for manipulating phrase matching.
Ordinarily, Tokens are assigned consecutive position numbers: 0, 1, and 2 for
"three blind mice".  However, if you set the position increment for "blind"
to, say, 1000, then the three tokens will end up assigned to positions 0, 1,
and 1001 -- and will no longer produce a phrase match for the query '"three
blind mice"'.

=back

=head1 METHODS

=head1 new

    my $token = KinoSearch::Analysis::Token->new(
        text         => $text,          # required 
        start_offset => 0,              # required 
        end_offset   => length($text),  # required
        boost        => 100.0,          # default 1.0
        pos_inc      => 0,              # default 1
    );

Constructor.  Takes hash-style parameters, corresponding to the token's
attributes.  

=head2 Accessors

Token provides these set/get methods:

=over 4

=item set_text

=item get_text

=item set_start_offset

=item get_start_offset

=item set_end_offset

=item get_end_offset

=item set_boost

=item get_boost

=item set_pos_inc

=item get_pos_inc

=back

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut

