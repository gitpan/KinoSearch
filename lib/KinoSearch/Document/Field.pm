package KinoSearch::Document::Field;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Index::FieldsReader;
use KinoSearch::Index::FieldInfos;
# Friends: KinoSearch::Index::FieldInfos

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args / members
    name                 => undef,
    analyzer             => undef,
    boost                => 1,
    stored               => 1,
    indexed              => 1,
    analyzed             => 1,
    binary               => 0,
    compressed           => 0,
    store_tv             => 0,
    store_offset_with_tv => 0,
    store_pos_with_tv    => 0,
    omit_norms           => 0,
    field_num            => undef,
    # members
    value         => '',
    fnm_bits      => undef,
    fdt_bits      => undef,
    terms         => [],
    start_offsets => [],
    end_offsets   => [],
    types         => undef,
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
}

# Given two Field objects, return a child which has all the positive
# attributes of both parents (meaning: values are OR'd).
sub breed_with {
    my ( $self, $other ) = @_;
    my $kid = $self->clone;
    for (qw( indexed store_tv store_offset_with_tv store_pos_with_tv )) {
        $kid->{$_} ||= $other->{$_};
    }
    return $kid;
}

__PACKAGE__->ready_get_set(
    qw(
        indexed
        stored
        analyzed
        binary
        compressed
        store_tv
        store_pos_with_tv
        store_offset_with_tv
        analyzer
        field_num
        terms
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

sub get_value_len { bytes::length $_[0]->{value} }

sub set_value {
    my ( $self, $val ) = @_;

    $self->{value} = $self->{terms}[0] = $val;
    $self->{end_offsets}[0] = bytes::length $val;
}

sub get_value { $_[0]->{value} }

sub set_tokenbatch {
    croak( "Expecting 4-5 arguments, but got " . scalar @_ )
        unless ( @_ == 4 or @_ == 5 );
    my $self = shift;
    @{$self}{ 'terms', 'start_offsets', 'end_offsets', 'types' } = @_;
}

sub get_tokenbatch {
    return @{ $_[0] }{ 'terms', 'start_offsets', 'end_offsets', 'types' };
}

1;

__END__

=head1 NAME

KinoSearch::Document::Field - a field within a document

=head1 SYNOPSIS

    # no public interface

=head1 DESCRIPTION

Fields can only be defined or manipulated indirectly, via InvIndexer and Doc.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=cut


