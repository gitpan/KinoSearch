package KinoSearch::Index::FieldInfos;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class Exporter );

use KinoSearch::Document::Field;

our @EXPORT_OK;

BEGIN {
    @EXPORT_OK = qw(
        INDEXED
        VECTORIZED
        OMIT_NORMS
    );
}

use constant INDEXED    => "\x01";
use constant VECTORIZED => "\x02";
use constant OMIT_NORMS => "\x10";

use Clone qw( clone );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members
    by_name   => {},
    by_num    => [],
    from_file => 0,
);

# Add a user-supplied Field object to the collection.
sub add_field {
    my ( $self, $field ) = @_;

    # don't mod Field objects for segments that are read back in
    croak("Can't update FieldInfos that were read in from file")
        if $self->{from_file};

    # misc verifications
    croak("Not a KinoSearch::Document::Field")
        unless a_isa_b( $field, 'KinoSearch::Document::Field' );
    my $fieldname = $field->get_name;
    croak("Field '$fieldname' already defined")
        if exists $self->{by_name}{$fieldname};

    # add the field
    $self->{by_name}{$fieldname} = $field;
    $self->_assign_field_nums;
}

# Return the number of fields in the segment.
sub size { scalar @{ $_[0]->{by_num} } }

# Return a list of the Field objects.
sub get_infos { @{ $_[0]->{by_num} } }

# Given a fieldname, return its number.
sub get_field_num {
    my ( $self, $name ) = @_;
    confess("don't have a field_num for field named '$name'")
        unless exists $self->{by_name}{$name};
    my $num = $self->{by_name}{$name}->get_field_num;
    return $num;
}

# Given a fieldname, return its FieldInfo.
sub info_by_name { $_[0]->{by_name}{ $_[1] } }

# Given a field number, return its fieldInfo.
sub info_by_num { $_[0]->{by_num}[ $_[1] ] }

# Given the field number (new, not original), return the name of the field.
sub field_name {
    my ( $self, $num ) = @_;
    my $name = $self->{by_num}[$num]->get_name;
    croak("Don't know about field number $num")
        unless defined $name;
    return $name;
}

# Sort all the fields lexically by name and assign ascending numbers.
sub _assign_field_nums {
    my $self = shift;
    confess("Can't _assign_field_nums when from_file") if $self->{from_file};

    # assign field nums according to lexical order of field names
    @{ $self->{by_num} }
        = sort { $a->get_name cmp $b->get_name } values %{ $self->{by_name} };
    my $inc = 0;
    $_->set_field_num( $inc++ ) for @{ $self->{by_num} };
}

# Decode an existing .fnm file.
sub read_infos {
    my ( $self,    $instream ) = @_;
    my ( $by_name, $by_num )   = @{$self}{qw( by_name by_num )};

    # set flag indicating that this FieldInfos object has been read in
    $self->{from_file} = 1;

    # read in infos from stream
    my $num_fields     = $instream->lu_read('V');
    my @names_and_bits = $instream->lu_read( 'Ta' x $num_fields );
    my $field_num      = 0;
    while ( $field_num < $num_fields ) {
        my ( $name, $bits ) = splice( @names_and_bits, 0, 2 );
        my $info = KinoSearch::Document::Field->new(
            field_num  => $field_num,
            name       => $name,
            indexed    => ( "$bits" & INDEXED ) eq INDEXED ? 1 : 0,
            vectorized => ( "$bits" & VECTORIZED ) eq VECTORIZED ? 1 : 0,
            fnm_bits   => $bits,
        );
        $by_name->{$name} = $info;
        # order of storage implies lexical order by name and field number
        push @$by_num, $info;
        $field_num++;
    }
}

# Write .fnm file.
sub write_infos {
    my ( $self, $outstream ) = @_;

    $outstream->lu_write( 'V', scalar @{ $self->{by_num} } );
    for my $finfo ( @{ $self->{by_num} } ) {
        $outstream->lu_write( 'Ta', $finfo->get_name, $finfo->get_fnm_bits, );
    }
}

# Merge two FieldInfos objects, redefining fields as necessary and generating
# new field numbers.
sub consolidate {
    my ( $self, @others ) = @_;
    my $infos = $self->{by_name};

    # Make *this* finfos the master FieldInfos object
    for my $other (@others) {
        while ( my ( $name, $other_finfo ) = each %{ $other->{by_name} } ) {
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
    #    for my $other (@others) {
    #        for my $other_finfo ( @{ $other->{by_num} } ) {
    #            $other_finfo->{field_num}
    #                = $infos->{"$other_finfo->{name}"}{field_num};
    #        }
    #    }
}

sub encode_fnm_bits {
    my ( undef, $field ) = @_;
    my $bits = "\0";
    for ($bits) {
        $_ |= INDEXED    if $field->get_indexed;
        $_ |= VECTORIZED if $field->get_vectorized;
        $_ |= OMIT_NORMS if $field->get_omit_norms;
    }
    return $bits;
}

sub decode_fnm_bits {
    my ( undef, $field, $bits ) = @_;
    $field->set_indexed(    ( $bits & INDEXED )    eq INDEXED );
    $field->set_vectorized( ( $bits & VECTORIZED ) eq VECTORIZED );
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
have this property. 

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.06.

=end devdocs
=cut

