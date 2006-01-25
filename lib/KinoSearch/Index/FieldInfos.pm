package KinoSearch::Index::FieldInfos;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class Exporter );

use KinoSearch::Document::Field;

our @EXPORT_OK;

BEGIN {
    @EXPORT_OK = qw(
        INDEXED
        STORE_TV
        STORE_POS_WITH_TV
        STORE_OFFSET_WITH_TV
        OMIT_NORMS
    );
}

use constant INDEXED              => "\x01";
use constant STORE_TV             => "\x02";
use constant STORE_POS_WITH_TV    => "\x04";
use constant STORE_OFFSET_WITH_TV => "\x08";
use constant OMIT_NORMS           => "\x10";

use Clone qw( clone );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members
    infos        => {},
    orig_order   => undef,
    sorted_names => [],
    from_file    => 0,
);

# Create a FieldInfo from from a user-supplied Field object and add it to the
# FieldInfos collection.
sub add_field {
    my ( $self, $field ) = @_;

    # don't mod Field objects for segments that are read back in
    croak("Can't update FieldInfos that were read in from file")
        if $self->{from_file};

    # misc verifications
    croak("Not a KinoSearch::Document::Field")
        unless ( blessed($field)
        and ( $field->isa('KinoSearch::Document::Field') ) );
    my $fieldname = $field->get_name;
    croak("Field '$fieldname' already defined")
        if exists $self->{infos}{$fieldname};

    # add the field
    $self->{infos}{$fieldname} = $field;
    $self->_assign_field_nums;
}

# Return the number of fields in the segment.
sub size { scalar @{ $_[0]->{sorted_names} } }

# Return an unordered list of the FieldInfo objects.
sub get_infos {
    values %{ $_[0]->{infos} };
}

# Given a fieldname, return its number.
sub get_field_num {
    my ( $self, $name ) = @_;
    my $num = $self->{infos}{$name}{field_num};
    confess("don't have a field_num for field named '$name'")
        unless defined $num;
    return $num;
}

# Given a fieldname, return its FieldInfo.
sub info_by_name { $_[0]->{infos}{ $_[1] } }

# Given the *original* field number return a fieldInfo.
sub info_by_orig_num { $_[0]->{orig_order}[ $_[1] ] }

# Given the field number (new, not original), return the name of the field.
sub field_name {
    my ( $self, $num ) = @_;
    my $name = $self->{sorted_names}[$num];
    croak("Don't know about field number $num")
        unless defined $name;
    return $name;
}

# Return a mapping of original field numbers to new.
sub get_fnum_map {
    my $self     = shift;
    my $fnum_map = '';
    $fnum_map .= pack( 'n', $_->{field_num} ) for @{ $self->{orig_order} };
    return $fnum_map;
}

# Sort all the fields lexically by name and assign ascending numbers.
sub _assign_field_nums {
    my $self  = shift;
    my $infos = $self->{infos};

    # assign field nums according to lexical order of field names
    my @sorted = sort { $a->{name} cmp $b->{name} } values %$infos;
    my $inc = 0;
    $_->{field_num} = $inc++ for @sorted;
    @{ $self->{sorted_names} } = map { $_->{name} } @sorted;

    # preserve original order in orig_order array if read from file
    $self->{orig_order} = \@sorted
        unless $self->{from_file};
}

# Decode an existing .fnm file.
sub read_infos {
    my ( $self, $instream ) = @_;
    my %infos;
    $self->{infos} = \%infos;

    # set flag indicating that this FieldInfos object has been read in
    $self->{from_file} = 1;

    # read in infos from stream
    my $num_fields     = $instream->lu_read('V');
    my @names_and_bits = $instream->lu_read( 'Ta' x $num_fields );
    my @orig;
    for ( 0 .. $num_fields - 1 ) {
        my ( $name, $bits ) = splice( @names_and_bits, 0, 2 );
        my $info = KinoSearch::Document::Field->new(
            name     => $name,
            indexed  => ( "$bits" & INDEXED ) eq INDEXED ? 1 : 0,
            store_tv => ( "$bits" & STORE_TV ) eq STORE_TV ? 1 : 0,
            store_pos_with_tv => ( "$bits" & STORE_POS_WITH_TV ) eq
                STORE_POS_WITH_TV ? 1 : 0,
            store_offset_with_tv => ( "$bits" & STORE_OFFSET_WITH_TV ) eq
                STORE_OFFSET_WITH_TV ? 1 : 0,
            fnm_bits => $bits,
        );
        $infos{$name} = $info;
        push @orig, $info;
    }

    # preserve original field numbers
    $self->{orig_order} = \@orig;

    # force KinoSearch compatible field numbers
    $self->_assign_field_nums;
}

# Write .fnm file.
sub write_infos {
    my ( $self, $outstream ) = @_;

    my @sorted_infos = sort { $a->get_field_num cmp $b->get_field_num }
        values %{ $self->{infos} };
    $outstream->lu_write( 'V', scalar @sorted_infos );
    for my $finfo (@sorted_infos) {
        $outstream->lu_write( 'Ta', $finfo->get_name, $finfo->get_fnm_bits, );
    }
}

# Merge two FieldInfos objects, redefining fields as necessary and generating
# new field numbers.
sub consolidate {
    my ( $self, @others ) = @_;
    my $infos = $self->{infos};

    # create a master FieldInfos object
    for my $other (@others) {
        while ( my ( $name, $other_finfo ) = each %{ $other->{infos} } ) {
            if ( exists $infos->{$name} ) {
                $infos->{$name} = $other_finfo->breed_with( $infos->{$name} );
            }
            else {
                $infos->{$name} = clone($other_finfo);
            }
        }
    }

    $self->_assign_field_nums;

    # sync field nums in all the others with the master
    my @fnum_maps;
    for my $other (@others) {
        for my $other_finfo ( @{ $other->{orig_order} } ) {
            $other_finfo->{field_num}
                = $infos->{"$other_finfo->{name}"}{field_num};
        }
    }
}

sub encode_fnm_bits {
    my ( undef, $field ) = @_;
    my $bits = "\0";
    for ($bits) {
        $_ |= INDEXED              if $field->get_indexed;
        $_ |= STORE_TV             if $field->get_store_tv;
        $_ |= STORE_POS_WITH_TV    if $field->get_store_pos_with_tv;
        $_ |= STORE_OFFSET_WITH_TV if $field->get_store_offset_with_tv;
        $_ |= OMIT_NORMS           if $field->get_omit_norms;
    }
    return $bits;
}

sub decode_fnm_bits {
    my ( undef, $field, $bits ) = @_;
    $field->set_indexed(  ( $bits & INDEXED )  eq INDEXED );
    $field->set_store_tv( ( $bits & STORE_TV ) eq STORE_TV );
    $field->set_store_pos_with_tv(
        ( $bits & STORE_POS_WITH_TV ) eq STORE_POS_WITH_TV );
    $field->set_store_offset_with_tv(
        ( $bits & STORE_OFFSET_WITH_TV ) eq STORE_OFFSET_WITH_TV );
    $field->set_omit_norms( ( $bits & OMIT_NORMS ) eq OMIT_NORMS );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::FieldInfos - track field characteristics

=head1 SYNOPSIS

    my $finfos = KinoSearch::Index::FieldInfos->new;
    $finfos->read_infos($instream);

=head1 DESCRIPTION

A FieldInfos object tracks the characteristics of all fields in a given
segment.

KinoSearch counts on having field nums assigned to fields by lexically sorted
order of field names, but indexes generated by Java Lucene are not likely to
have this property.  In order to keep this area of KinoSearch
Lucene-compatible, it is necessary to prepare for unordered field numbers.

When an index is read in, original field numbers are preserved via the
orig_order array, but then the field numbers visible to the rest of KinoSearch
are forced into an order corresponding to lexically sorted field name.

The fnum_map, which maps original field numbers to new, is used by various
classes within KinoSearch to translate.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05.

=end devdocs
=cut

