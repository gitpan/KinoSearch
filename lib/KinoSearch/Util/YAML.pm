use strict;
use warnings;

package KinoSearch::Util::YAML;
use KinoSearch::Util::ToolSet;
use base qw( Exporter );

our @EXPORT_OK = qw( encode_yaml parse_yaml );

use KinoSearch::Util::ByteBuf;
use KinoSearch::Util::Hash;
use KinoSearch::Util::VArray;
use KinoSearch::Util::CClass qw( to_kino );

sub encode_yaml {
    my $input = shift;
    my $output;
    if ( a_isa_b( $input, 'KinoSearch::Util::Obj' ) ) {
        $output = _encode_yaml($input);
    }
    else {
        $output = _encode_yaml( to_kino($input) );
    }
    return $output->to_perl if defined $output;
}

sub parse_yaml {
    my $input = shift;
    my $output;
    if ( a_isa_b( $input, 'KinoSearch::Util::ByteBuf' ) ) {
        $output = _parse_yaml($input);
    }
    else {
        $output = _parse_yaml( KinoSearch::Util::ByteBuf->new($input) );
    }
    return $output->to_perl if defined $output;
    return;
}

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::YAML

SV*
_encode_yaml(obj)
    kino_Obj *obj;
CODE:
{
    kino_ByteBuf *bb = kino_YAML_encode_yaml(obj);
    RETVAL = bb == NULL
        ? newSV(0)
        : kobj_to_pobj(bb);
    REFCOUNT_DEC(bb);
}
OUTPUT: RETVAL

SV*
_parse_yaml(input);
    kino_ByteBuf *input;
CODE:
{
    kino_Obj *parsed = kino_YAML_parse_yaml(input);
    RETVAL = parsed == NULL 
        ? newSV(0)
        : kobj_to_pobj(parsed);
    REFCOUNT_DEC(parsed);
}
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::YAML - Parse a very limited subset of YAML.

=head1 DESCRIPTION

KinoSearch uses a strict, limited subset of YAML for serializing data within
some index files.  Each line must conform to one of four formats:

    key: value
    key:
    - value
    -

End of line comments beginning with a pound sign are supported.

    # the following line has a comment
    key: value # hi there

The lines without a scalar value upon them imply that the value is a complex
data structure described on lines that follow, one indentation level deeper.

    # hash entry; the value is a three-element array
    key:
      - a
      - b
      - c

    # array element; the value is a hash with two key value pairs
    - 
      a: foo
      b: bar

Scalars may be delimited either by whitespace or single-quotes.
Whitespace-delimited scalars may not contain colons.  Single quotes within a
single-quoted scalar may be escaped by doubling them up.

    this::key::is::not::ok : 'but::this::value::is::ok'

    'this key is kosher': value
    key: 'this value''s kosher, too'

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

