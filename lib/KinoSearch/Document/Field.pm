package KinoSearch::Document::Field;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Index::FieldsReader;
use KinoSearch::Index::FieldInfos;
use KinoSearch::Index::TermVector;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args / members
    name       => undef,
    analyzer   => undef,
    boost      => 1,
    stored     => 1,
    indexed    => 1,
    analyzed   => 1,
    vectorized => undef,
    binary     => 0,
    compressed => 0,
    omit_norms => 0,
    field_num  => undef,
    value      => '',
    fnm_bits   => undef,
    fdt_bits   => undef,
    tv_string  => '',
    tv_cache   => undef,
);

sub init_instance {
    my $self = shift;

    # field name is required
    croak("Missing required parameter 'name'")
        unless length $self->{name};

    # don't index binary fields
    if ( $self->{binary} ) {
        $self->{indexed}  = 0;
        $self->{analyzed} = 0;
    }

    if ( !defined $self->{vectorized} ) {
        $self->{vectorized} = $self->{stored};
    }
}

# Given two Field objects, return a child which has all the positive
# attributes of both parents (meaning: values are OR'd).
sub breed_with {
    my ( $self, $other ) = @_;
    my $kid = $self->clone;
    for (qw( indexed vectorized )) {
        $kid->{$_} ||= $other->{$_};
    }
    return $kid;
}

__PACKAGE__->ready_get_set(
    qw(
        value
        tv_string
        boost
        indexed
        stored
        analyzed
        vectorized
        binary
        compressed
        analyzer
        field_num
        name
        omit_norms
        )
);

sub set_fnm_bits { $_[0]->{fnm_bits} = $_[1] }

sub get_fnm_bits {
    my $self = shift;
    $self->{fnm_bits} = KinoSearch::Index::FieldInfos->encode_fnm_bits($self)
        unless defined $self->{fnm_bits};
    return $self->{fnm_bits};
}

sub set_fdt_bits { $_[0]->{fdt_bits} = $_[1] }

sub get_fdt_bits {
    my $self = shift;
    $self->{fdt_bits}
        = KinoSearch::Index::FieldsReader->encode_fdt_bits($self)
        unless defined $self->{fdt_bits};
    return $self->{fdt_bits};
}

sub get_value_len { bytes::length( $_[0]->{value} ) }

sub term_vector {
    my ( $self, $term_text ) = @_;
    return unless bytes::length( $self->{tv_string} );
    if ( !defined $self->{tv_cache} ) {
        ( my %tv_cache ) = _extract_tv_cache( $self->{tv_string} );
        $self->{tv_cache} = \%tv_cache;
    }
    if ( exists $self->{tv_cache}{$term_text} ) {
        my ( $positions, $starts, $ends )
            = _unpack_posdata( $self->{tv_cache}{$term_text} );
        my $term_vector = KinoSearch::Index::TermVector->new(
            text          => $term_text,
            field         => $self->{name},
            positions     => $positions,
            start_offsets => $starts,
            end_offsets   => $ends,
        );
        return $term_vector;
    }

    return;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Document::Field

void
_extract_tv_cache(tv_string_sv)
    SV *tv_string_sv;
PREINIT:
    char    *tv_string, *bookmark_ptr;
    char   **tv_ptr;
    STRLEN   len, tv_len, overlap;
    SV      *text_sv, *nums_sv;
    I32      i, num_terms, num_positions;
PPCODE:
    tv_string = SvPV(tv_string_sv, tv_len);
    tv_ptr    = &tv_string;

    text_sv = newSV(1);
    SvPOK_on(text_sv);
    *(SvEND(text_sv)) = '\0';

    num_terms = Kino_InStream_decode_vint(tv_ptr);
    for (i = 0; i < num_terms; i++) {

        /* decompress the term text and push it onto the stack */
        overlap = Kino_InStream_decode_vint(tv_ptr);
        SvCUR_set(text_sv, overlap);
        len = Kino_InStream_decode_vint(tv_ptr);
        sv_catpvn(text_sv, *tv_ptr, len);
        *tv_ptr += len;
        XPUSHs(sv_2mortal( newSVsv(text_sv) ));

        /* put positions & offsets string on the stack */
        num_positions = Kino_InStream_decode_vint(tv_ptr);
        bookmark_ptr = *tv_ptr;
        while(num_positions--) {
            /* leave nums compressed to save a little mem */
            (void)Kino_InStream_decode_vint(tv_ptr);
            (void)Kino_InStream_decode_vint(tv_ptr);
            (void)Kino_InStream_decode_vint(tv_ptr);
        }
        len = *tv_ptr - bookmark_ptr;
        XPUSHs(sv_2mortal( newSVpvn(bookmark_ptr, len) ));
    }
    SvREFCNT_dec(text_sv);
    XSRETURN(num_terms * 2);

void
_unpack_posdata(posdata_sv)
    SV *posdata_sv;
PREINIT:
    STRLEN  len;
    char   *posdata, *posdata_end;
    AV     *positions_av, *starts_av, *ends_av;
    char  **posdata_ptr;
    SV     *num_sv;
PPCODE:
    positions_av = newAV();
    starts_av    = newAV();
    ends_av      = newAV();
    posdata      = SvPV(posdata_sv, len);
    posdata_ptr  = &posdata;
    posdata_end  = SvEND(posdata_sv);

    while(*posdata_ptr < posdata_end) {
        num_sv = newSViv( Kino_InStream_decode_vint(posdata_ptr) );
        av_push(positions_av, num_sv);
        num_sv = newSViv( Kino_InStream_decode_vint(posdata_ptr) );
        av_push(starts_av,    num_sv);
        num_sv = newSViv( Kino_InStream_decode_vint(posdata_ptr) );
        av_push(ends_av,      num_sv);
    }

    if (*posdata_ptr != posdata_end)
        Kino_confess("Bad encoding of posdata");
    XPUSHs(sv_2mortal( newRV_noinc((SV*)positions_av) ));
    XPUSHs(sv_2mortal( newRV_noinc((SV*)starts_av)    ));
    XPUSHs(sv_2mortal( newRV_noinc((SV*)ends_av)      ));
    XSRETURN(3);


__POD__

=head1 NAME

KinoSearch::Document::Field - a field within a document

=head1 SYNOPSIS

    # no public interface

=head1 DESCRIPTION

Fields can only be defined or manipulated indirectly, via InvIndexer and Doc.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=cut


