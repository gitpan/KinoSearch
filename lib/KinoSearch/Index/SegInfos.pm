use strict;
use warnings;

package KinoSearch::Index::SegInfos;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use Time::HiRes qw( time );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # params/members
        schema => undef,

        # members
        infos       => {},
        seg_counter => 0,
        version     => ( int( time * 1000 ) ),
        generation  => 0,
    );
    __PACKAGE__->ready_get_set(qw( seg_counter generation ));
}

use KinoSearch::Index::SegInfo;
use KinoSearch::Schema::FieldSpec;
use KinoSearch::Schema;
use KinoSearch::Index::IndexFileNames
    qw( filename_from_gen SEG_INFOS_FORMAT );
use KinoSearch::Util::CClass qw( to_kino to_perl );
use KinoSearch::Util::YAML qw( encode_yaml parse_yaml );

sub init_instance {
    my $self = shift;
    confess("Missing required parameter schema") unless defined
        $self->{schema};
}

# Add a SegInfo to the collection.
sub add_info {
    my ( $self, $info ) = @_;
    $self->{infos}{ $info->get_seg_name } = $info;
}

sub get_info {
    my ( $self, $seg_name ) = @_;
    my $info = $self->{infos}{$seg_name};
    confess("No segment named '$seg_name'") unless defined $info;
    return $info;
}

# Remove the info corresponding to a segment;
sub delete_segment {
    my ( $self, $seg_name ) = @_;
    confess("no segment named '$seg_name'")
        unless exists $self->{infos}{$seg_name};
    delete $self->{infos}{$seg_name};
}

# Return number of segments in folder.
sub size { scalar keys %{ $_[0]->{infos} } }

# Retrieve all infos.
sub infos {
    values %{ $_[0]->{infos} };
}

# Decode "segments" file.
sub read_infos {
    my ( $self, $folder ) = @_;
    my $schema   = $self->{schema};
    my $filename = $folder->latest_gen( 'segments', '.yaml' );
    return unless defined $filename;
    my $segs_data = parse_yaml( $folder->slurp_file($filename) );

    # check format
    confess("Unsupported seg infos format: '$segs_data->{format}'")
        unless $segs_data->{format} <= SEG_INFOS_FORMAT;

    $self->{seg_counter} = $segs_data->{seg_counter};
    $self->{generation}  = $segs_data->{generation};

    # Add any unknown fields to the Schema instance
    while ( my ( $field, $fspec_class ) = each %{ $segs_data->{fields} }) {
        if ( !$fspec_class->isa("KinoSearch::Schema::FieldSpec") ) {
            confess(  "Attempted to load field '$field' assigned to "
                    . "'$fspec_class', but '$fspec_class' isn't a "
                    . "KinoSearch::Schema::FieldSpec" );
        }
        $schema->add_field( $field, $fspec_class );
    }

    # build one SegInfo object for each segment
    return unless defined $segs_data->{segments};
    while ( my ( $seg_name, $seg_meta ) = each %{ $segs_data->{segments} } ) {
        $self->{infos}{$seg_name} = KinoSearch::Index::SegInfo->new(
            seg_name => $seg_name,
            metadata => to_kino($seg_meta),
        );
    }
}

# Write "segments" file.
sub write_infos {
    my ( $self, $folder ) = @_;
    my $schema = $self->{schema};

    # increment the filename and the generation
    $self->{generation}++;
    $self->{version}++;

    # build a hash of field_name => fspec_class pairings
    my %fields
        = map { $_ => ref( $schema->fetch_fspec($_) ) } $schema->all_fields;

    # create a YAML-izable data structure
    my %data = (
        format      => SEG_INFOS_FORMAT,
        fields      => \%fields,
        version     => $self->{version},
        ks_version  => $KinoSearch::VERSION,
        seg_counter => $self->{seg_counter},
        generation  => $self->{generation},
    );
    my %segments;
    for ( values %{ $self->{infos} } ) {
        $segments{ $_->get_seg_name } = $_->get_metadata;
    }
    $data{segments} = \%segments if scalar keys %segments;

    # write out YAML-ized data to a provisional file
    my $outstream = $folder->open_outstream('segments.new');
    $outstream->print( encode_yaml( \%data ) );
    $outstream->sclose;

    # rename the file, making the new index revision active
    my $filename
        = filename_from_gen( "segments", $self->{generation}, ".yaml" );
    $folder->rename_file( "segments.new", $filename );
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegInfos - Manage segment statistical data.

=head1 DESCRIPTION

SegInfos ties together the segments which make up an folder.  It stores a
little information about each, plus some unifying information such as the
counter used to name new segments.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

