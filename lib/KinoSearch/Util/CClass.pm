use strict;
use warnings;

package KinoSearch::Util::CClass;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj Exporter );

our @EXPORT_OK = qw( to_kino to_perl );

use KinoSearch::Util::Hash;
use KinoSearch::Util::ByteBuf;
use KinoSearch::Util::VArray;

# Translate a complex data structure in Perl to the equivalent in KinoSearch C
# structures.  Undefined elements will trigger a warning and be turned to
# empty strings.
sub to_kino {
    my $input   = shift;
    my $reftype = reftype($input);

    if ( !$reftype ) {
        return KinoSearch::Util::ByteBuf->new($input);
    }
    elsif ( $reftype eq 'HASH' ) {
        my $capacity = scalar keys %$input;
        my $hash = KinoSearch::Util::Hash->new( capacity => $capacity );
        while ( my ( $k, $v ) = each %$input ) {
            my $val = to_kino($v);
            $hash->store( $k, $val );
        }
        return $hash;
    }
    elsif ( $reftype eq 'ARRAY' ) {
        my $varray
            = KinoSearch::Util::VArray->new( capacity => scalar @$input );
        $varray->push( to_kino($_) ) for @$input;
        return $varray;
    }
    elsif ( a_isa_b( $input, 'KinoSearch::Util::Obj' ) ) {
        return $input;
    }
}

# Transform what may or may not be a KinoSearch object into a Perl complex
# data structure if possible.
sub to_perl {
    my $input = shift;
    if ( ref($input) and $input->can('to_perl') ) {
        return $input->to_perl;
    }
    else {
        return $input;
    }
}

sub _test { return scalar @_ }

sub _test_obj {
    if ( !defined $KinoSearch::Util::CClass::testobj ) {
        $KinoSearch::Util::CClass::testobj = __PACKAGE__->_new;
    }
    return $KinoSearch::Util::CClass::testobj;
}

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::CClass

=for comment

These are all for testing purposes only.

=cut

kino_CClass*
_new(class)
    const classname_char *class;
CODE:
    RETVAL = kino_CClass_new();
    KINO_UNUSED_VAR(class);
OUTPUT: RETVAL

void
_callback(self)
    kino_Obj *self;
PPCODE:
{
    kino_ByteBuf bb = KINO_BYTEBUF_BLANK; 
    kino_CClass_callback(self, "_test", &bb, &bb, &bb, NULL);
}

SV*
_callback_bb(self);
    kino_Obj *self;
CODE:
{
    kino_ByteBuf bb = KINO_BYTEBUF_BLANK; 
    kino_ByteBuf *val = kino_CClass_callback_bb(self, "_test", &bb, &bb, 
        &bb, NULL);
    RETVAL = bb_to_sv(val);
    REFCOUNT_DEC(val);
}
OUTPUT: RETVAL

    
IV
_callback_i(self)
    kino_Obj *self;
CODE:
{
    kino_ByteBuf bb = KINO_BYTEBUF_BLANK;
    RETVAL = kino_CClass_callback_i(self, "_test", &bb, &bb, &bb, NULL);
}
OUTPUT: RETVAL

float
_callback_f(self)
    kino_Obj *self;
CODE:
{
    kino_ByteBuf bb = KINO_BYTEBUF_BLANK;
    RETVAL = kino_CClass_callback_f(self, "_test", &bb, &bb, &bb, NULL);
}
OUTPUT: RETVAL

SV*
_callback_obj(self)
    kino_Obj *self;
CODE: 
{
    kino_ByteBuf bb = KINO_BYTEBUF_BLANK;
    kino_Obj *other = kino_CClass_callback_obj( self, "_test_obj", &bb, 
        &bb, &bb, NULL);
    RETVAL = kobj_to_pobj(other);
}
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::CClass - Callbacks to Perl from C.

=head1 DESCRIPTION

A framework for KinoSearch's C objects to use when calling back to Perl.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
