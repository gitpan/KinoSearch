package KinoSearch::Index::NormsReader;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        instream => undef,
        max_doc  => undef,
        bytes    => undef,
    );
}

sub init_instance {
    my $self = shift;
    confess("Internal error: max_doc is required")
        unless defined $self->{max_doc};
}

# return a reference to a byte-array of norms
sub get_bytes {
    my $self = shift;
    $self->_ensure_read;
    return \$self->{bytes};
}

# Lazily read in the raw array of norms.
sub _ensure_read {
    my $self = shift;
    if ( !defined $self->{bytes} ) {
        $self->{bytes} = $self->{instream}->lu_read( 'a' . $self->{max_doc} );
    }
}

sub close { shift->{instream}->close }

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::NormsReader - read field normalization data

=head1 DESCRIPTION

NormsReader accesses the encoded norms which are built up, one byte per
document, for indexed fields.

=head1 SEE ALSO

L<KinoSearch::Search::Similarity|KinoSearch::Search::Similarity>

=head1 TODO

Make "fake" norms possible, for fields where the norm is useless, like unique
id fields.

=head1 COPYRIGHT

Copyright 2005-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.165.

=end devdocs
=cut

