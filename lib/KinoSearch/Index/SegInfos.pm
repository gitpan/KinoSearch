package KinoSearch::Index::SegInfos;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use Time::HiRes qw( time );

use constant FORMAT => -1;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members
    infos   => [],
    counter => 0,
    version => ( time * 1000 ),
);

# Add a SegInfo to the collection.
sub add_info { push @{ $_[0]->{infos} }, $_[1] }

# Return number of segments in invindex.
sub size { scalar @{ $_[0]->{infos} } }

# Retrieve a SegInfo by array index.
sub info { $_[0]->{infos}[ $_[1] ] }

# Get/set counter, which is used to name new segments.
sub get_counter { $_[0]->{counter} }
sub set_counter { $_[0]->{counter} = $_[1] }

# Decode "segments" file.
sub read_infos {
    my ( $self, $invindex ) = @_;
    my $instream = $invindex->open_instream('segments');

    # support only recent index formats
    my $format = $instream->lu_read('i');
    croak("unsupported format: '$format'")
        unless $format == FORMAT;

    # read header
    @{$self}{ 'version', 'counter' } = $instream->lu_read('Qi');
    my $num_segs = $instream->lu_read('i');

    # build one SegInfo object for each segment
    if ($num_segs) {
        my @file_contents = $instream->lu_read( 'Ti' x $num_segs );
        while (@file_contents) {
            push @{ $self->{infos} },
                KinoSearch::Index::SegInfo->new(
                seg_name  => shift @file_contents,
                doc_count => shift @file_contents,
                invindex  => $invindex,
                );
        }
    }
}

# Write "segments" file
sub write_infos {
    my ( $self, $invindex ) = @_;
    my $num_segs  = scalar @{ $self->{infos} };
    my $outstream = $invindex->open_outstream('segments.new');

    # prepare header
    $self->{version}++;
    my @outstuff = ( FORMAT, $self->{version}, $self->{counter}, $num_segs );

    # prepare data
    push @outstuff, ( $_->{seg_name}, $_->{doc_count} )
        for @{ $self->{infos} };

    # write it all out
    my $template = 'iQii' . ( 'Ti' x $num_segs );
    $outstream->lu_write( $template, @outstuff );
    $outstream->close;

    # clobber the old segments file
    $invindex->rename_file( "segments.new", "segments" );
}

package KinoSearch::Index::SegInfo;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    seg_name  => '',
    doc_count => 0,
    invindex  => undef,
);

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegInfos - manage segment statistical data

=head1 DESCRIPTION

SegInfos ties together the segments which make up an invindex.  It stores a
little information about each, plus some unifying information such as the
counter used to name new segments.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.08.

=end devdocs
=cut

