use strict;
use warnings;

package KinoSearch::Index::DocReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        folder   => undef,
        schema   => undef,
        seg_info => undef,
        # members
        ds_in  => undef,
        dsx_in => undef,
        size   => undef,
    );
}

use Compress::Zlib qw( uncompress );
use KinoSearch::Util::StringHelper qw( utf8_flag_on );
use KinoSearch::Index::IndexFileNames qw( DOC_STORAGE_FORMAT );

sub init_instance {
    my $self = shift;
    my ( $folder, $seg_info ) = @{$self}{qw( folder seg_info )};

    # check format
    my $metadata = $seg_info->extract_metadata('doc_storage');
    confess("Unsupported doc storage format: '$metadata->{format}'")
        unless $metadata->{format} <= DOC_STORAGE_FORMAT;

    my $seg_name = $seg_info->get_seg_name;

    $self->{ds_in}  = $folder->open_instream("$seg_name.ds");
    $self->{dsx_in} = $folder->open_instream("$seg_name.dsx");

    # derive the number of documents in the segment
    $self->{size} = $self->{dsx_in}->slength / 8;
}

# Return number of documents in segment.
sub get_size { $_[0]->{size} }

sub read_record {
    my ( $self, $doc_num, $field_num_map ) = @_;
    my ( $dsx_in, $ds_in ) = @{$self}{ 'dsx_in', 'ds_in' };

    $dsx_in->sseek( $doc_num * 8 );
    my $file_ptr      = $dsx_in->lu_read('Q');
    my $next_file_ptr =
          $doc_num == $self->{size} - 1
        ? $ds_in->slength
        : $dsx_in->lu_read('Q');

    my $record_len = $next_file_ptr - $file_ptr;

    $ds_in->sseek($file_ptr);

    # if not remapping, record can be copied whole */
    if ( !defined $field_num_map ) {
        my $record = $ds_in->lu_read("a$record_len");
        return \$record;
    }
    # we have to map field numbers
    else {
        return _read_and_remap( $ds_in, $field_num_map, $record_len );
    }
}

# Given a doc_num, rebuild a document from the fields that were stored.
sub fetch_doc {
    my ( $self, $doc_num ) = @_;
    my ( $schema, $seg_info, $dsx_in, $ds_in )
        = @{$self}{qw( schema seg_info dsx_in ds_in )};
    my %doc;

    # get data file pointer from index, read number of fields
    $dsx_in->sseek( $doc_num * 8 );
    my $start = $dsx_in->lu_read('Q');
    $ds_in->sseek($start);
    my $num_fields = $ds_in->lu_read('V');

    # docode stored data and build up the doc field by field.
    for ( 1 .. $num_fields ) {
        my $field_num  = $ds_in->lu_read('V');
        my $field_name = $seg_info->field_name($field_num);
        my $field_spec = $schema->fetch_fspec($field_name);

        # condition the value
        if ( $field_spec->compressed ) {
            $doc{$field_name} = uncompress( $ds_in->lu_read('T') );
        }
        else {
            $doc{$field_name} = $ds_in->lu_read('T');
        }
        utf8_flag_on( $doc{$field_name} ) unless $field_spec->binary;
    }

    return \%doc;
}

sub close {
    my $self = shift;
    $self->{ds_in}->sclose;
    $self->{dsx_in}->sclose;
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::DocReader

SV*
_read_and_remap(ds_in, field_num_map, record_len)
    kino_InStream *ds_in;
    kino_IntMap   *field_num_map;
    IV             record_len;
CODE:
{
    kino_u32_t i;
    kino_u32_t num_fields;
    char vint_bufbuf[10];
    char *vint_buf = vint_bufbuf;
    size_t vint_bytes;
    SV *target = newSV(record_len);

    SvPOK_on(target);
    
    /* re-encode number of fields */
    num_fields = Kino_InStream_Read_VInt(ds_in);
    vint_bytes = kino_OutStream_encode_vint(num_fields, vint_buf);
    sv_catpvn(target, vint_buf, vint_bytes);

    /* copy strings */
    for (i = 0; i < num_fields; i++) {
        kino_u32_t field_string_len;
        kino_u32_t field_num     = Kino_InStream_Read_VInt(ds_in);
        kino_i32_t new_field_num = Kino_IntMap_Get(field_num_map, field_num);

        /* verify and write remapped field num */
        if (new_field_num == -1)
            CONFESS("Don't recognize field_num '%ld'", field_num);
        vint_bytes = kino_OutStream_encode_vint(new_field_num, vint_buf);
        sv_catpvn(target, vint_buf, vint_bytes);

        /* write field string length */
        field_string_len = Kino_InStream_Read_VInt(ds_in);
        vint_bytes = kino_OutStream_encode_vint(field_string_len, vint_buf);
        sv_catpvn(target, vint_buf, vint_bytes);
        
        /* write field string bytes */
        SvGROW(target, SvCUR(target) + field_string_len);
        Kino_InStream_Read_Bytes(ds_in, SvEND(target), field_string_len);
        SvCUR_set(target, SvCUR(target) + field_string_len);
    }

    RETVAL = newRV_noinc(target);
}
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::DocReader - Retrieve stored documents.

=head1 DESCRIPTION

DocReader's purpose is to retrieve stored documents from the InvIndex.  In
addition to returning fully decoded Doc objects, it can pass on raw data --
for instance, compressed fields stay compressed -- for the purpose of merging
segments efficiently.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
