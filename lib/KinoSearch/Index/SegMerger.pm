package KinoSearch::Index::SegMerger;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

=for comment

This module is NOT DONE.

=cut

our %instance_vars = __PACKAGE__->init_instance_vars(
    invindex  => undef,
    out_seg   => undef,
    segments  => [],
    doc_remap => {},
);

sub init_instance {
    my $self = shift;

    %$self = ( %$self, @_ );
}

sub retrieve_docs {
    my $self = shift;
    #my $deletions =
}

sub retrieve_postings {
    my $self    = shift;
    my $segment = $self->{segments}[0];
    $self->{segment};

}

sub add_segment {
    #@(@{ $self->{segments} }, $new_seg);
}

sub generate_doc_remap {
    my ( $self, $segment ) = @_;

    my @deletions = $segment->get_deletions;
    my %remapped;
    my $candidate = $segment->size - 1;
    @remapped{@deletions} = (undef) x scalar @deletions;
    my $highest_deletion = $deletions[-1];
    for (@deletions) {
        while ( exists $remapped{$candidate} ) {
            $candidate--;
        }
        # stop if all the docs above the deletion have been remapped.
        last if $candidate < $_;
        $remapped{$_} = $candidate--;
    }
    my $size      = $segment->size - scalar @{ $segment->get_deletions };
    my $remap_str = "\0" x ( ceil( int( $size / 8 ) ) );

    return \%remapped;
}

sub merge {
    my $self = shift;
    $self->consolidate_first_seg;

    for my $segment ( @{ $self->{segments} } ) {
        my $doc_remap = $self->generate_doc_remap($segment);
    }
}

sub consolidate_first_seg {
    my $self = shift;

    my $first_seg = $self->{segments}[0];
    my $doc_remap = $self->generate_doc_remap;

    my $num_to_write
        = $first_seg->size - scalar @{ $first_seg->get_deletions };
    for ( 0 .. $num_to_write - 1 ) {
        my $num_to_retrieve = exists $doc_remap->{$_} ? $doc_remap->{$_} : $_;
        #$outseg->store_doc(
        #    $first_seg->{doc_reader}->get_doc($num_to_retrieve),
        #);
    }
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegMerger - consolidate segments of an invindex

=head1 DESCRIPTION 

This module is NOT DONE.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut
