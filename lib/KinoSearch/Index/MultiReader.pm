package KinoSearch::Index::MultiReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

=for comment

This module is NOT DONE.

=cut

use KinoSearch::Index::SegReader;

our %instance_vars = __PACKAGE__->init_instance_vars(
    kindex      => undef,
    sub_readers => [],
    starts      => [],
    max_doc     => 0,
    version     => undef,
);

sub init_instance {
    my $self = shift;

    %$self = ( %$self, @_ );
    $self->_init_sub_readers;
}

sub _init_sub_readers {
    my $self   = shift;
    my $kindex = $self->{kindex};

    my $segments_instream = $self->{kindex}->open_instream('segments');
    my ($format) = $segments_instream->lu_read('i');
    croak("Unrecognized format: '$format'") unless $format == -1;

    my $num_segs;
    ( $self->{version}, $num_segs ) = $segments_instream->lu_read('Qi');
    my @names_and_sizes = $segments_instream->lu_read( 'Ti' x $num_segs );
    my @starts;
    my $doc_num_offset = 0;
    while (@names_and_sizes) {
        my $seg_name = shift @names_and_sizes;
        my $num_docs = shift @names_and_sizes;
        push @{ $self->{sub_readers} },
            KinoSearch::Index::SegReader->new(
            kindex         => $kindex,
            seg_name       => $seg_name,
            size           => $num_docs,
            doc_num_offset => $doc_num_offset,
            );
        push @starts, $doc_num_offset;
        $doc_num_offset += $num_docs;
    }
    $self->{starts}  = \@starts;
    $self->{max_doc} = $doc_num_offset;

}

sub term_docs {
    my ( $self, $termstring ) = shift;

    return KinoSearch::Index::MultiTermDocs->new(
        sub_readers => $self->{sub_readers},
        starts      => $self->{starts},
        termstring  => $termstring,
    );
}

sub norms {
    my ( $self, $field_num ) = @_;
    my $norm = '';
    for my $seg_reader ( @{ $self->{sub_readers} } ) {
        $norm .= $seg_reader->norms($field_num);
    }
    return $norm;
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::MultiReader - read from a multi-segment invindex

=head1 DESCRIPTION 

This module is NOT DONE.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut
