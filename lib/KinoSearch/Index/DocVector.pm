use strict;
use warnings;

package KinoSearch::Index::DocVector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # members
        field_strings => {},
        field_vectors => {},
    );

}
our %instance_vars;
use KinoSearch::Index::TermVector;

sub term_vector {
    my ( $self, $field, $term_text ) = @_;
    my $field_vector = $self->{field_vectors}{$field};

    # if no cache hit, try to fill cache
    if ( !defined $field_vector ) {
        my $field_string = $self->{field_strings}{$field};

        # bail if there's no content or the field isn't vectorized
        return unless defined $field_string;

        $field_vector = $self->{field_vectors}{$field}
            = _extract_tv_cache($field_string);
    }

    # get a field string for the text or bail
    my $tv_string = $field_vector->{$term_text};
    return unless defined $tv_string;

    my ( $positions, $starts, $ends ) = _extract_posdata($tv_string);

    return KinoSearch::Index::TermVector->new(
        field         => $field,
        text          => $term_text,
        positions     => $positions,
        start_offsets => $starts,
        end_offsets   => $ends,
    );
}

sub add_field_string {
    my ( $self, $field, $string ) = @_;
    $self->{field_strings}{$field} = $string;
}

sub field_string {
    return $_[0]->{field_strings}{ $_[1] };
}

sub get_field_names {
    return sort keys %{ $_[0]->{field_strings} };
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::DocVector

void
_extract_tv_cache(tv_string_sv)
    SV *tv_string_sv;
PPCODE:
{
    HV *tv_cache_hv = kino_DocVec_extract_tv_cache(tv_string_sv);
    XPUSHs( sv_2mortal( newRV_noinc( (SV*)tv_cache_hv ) ) );
    XSRETURN(1);
}

void
_extract_posdata(posdata_sv)
    SV *posdata_sv;
PPCODE:
{
    AV *positions_av = newAV();
    AV *starts_av    = newAV();
    AV *ends_av      = newAV();
    kino_DocVec_extract_posdata(posdata_sv, positions_av, starts_av, ends_av);
    XPUSHs(sv_2mortal( newRV_noinc((SV*)positions_av) ));
    XPUSHs(sv_2mortal( newRV_noinc((SV*)starts_av)    ));
    XPUSHs(sv_2mortal( newRV_noinc((SV*)ends_av)      ));
    XSRETURN(3);
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::DocVector - A collection of TermVectors.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


