package KinoSearch::Index::SegReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::IndexReader );

use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::TermInfosReader;
use KinoSearch::Index::FieldsReader;
use KinoSearch::Index::FieldInfos;
use KinoSearch::Index::NormsReader;
use KinoSearch::Index::SegTermDocs;
use KinoSearch::Index::DelDocs;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # params/members
    invindex => undef,
    seg_name => undef,

    # members
    comp_file_reader => undef,
    tinfos_reader    => undef,
    finfos           => undef,
    fields_reader    => undef,
    freq_stream      => undef,
    prox_stream      => undef,
    deldocs          => undef,
    norms_readers    => {},
);

__PACKAGE__->ready_get(qw( freq_stream prox_stream deldocs ));

# use KinoSearch::Util::Class's new()
# Note: can't inherit IndexReader's new() without recursion problems
*new = *KinoSearch::Util::Class::new;

sub init_instance {
    my $self = shift;
    my ( $seg_name, $invindex ) = @{$self}{ 'seg_name', 'invindex' };

    # initialize DelDocs
    $self->{deldocs} = KinoSearch::Index::DelDocs->new(
        invindex => $invindex,
        seg_name => $seg_name,
    );
    $self->{deldocs}->read_deldocs( $invindex, "$seg_name.del" )
        if ( $self->has_deletions );

    # initialize a CompoundFileReader
    my $comp_file_reader = $self->{comp_file_reader}
        = KinoSearch::Index::CompoundFileReader->new(
        invindex => $invindex,
        seg_name => $seg_name,
        );

    # initialize FieldInfos
    my $finfos = $self->{finfos} = KinoSearch::Index::FieldInfos->new;
    $finfos->read_infos( $comp_file_reader->open_instream("$seg_name.fnm") );

    # initialize FieldsReader
    $self->{fields_reader} = KinoSearch::Index::FieldsReader->new(
        finfos        => $finfos,
        fdata_stream  => $comp_file_reader->open_instream("$seg_name.fdt"),
        findex_stream => $comp_file_reader->open_instream("$seg_name.fdx"),
    );

    # initialize TermInfosReader
    $self->{tinfos_reader} = KinoSearch::Index::TermInfosReader->new(
        invindex => $comp_file_reader,
        seg_name => $seg_name,
        finfos   => $finfos,
    );

    # open the frequency data, the positional data, and the norms
    $self->{freq_stream} = $comp_file_reader->open_instream("$seg_name.frq");
    $self->{prox_stream} = $comp_file_reader->open_instream("$seg_name.prx");
    $self->_open_norms;

    # TODO open termvectors
}

sub max_doc { shift->{fields_reader}->get_size }

sub has_deletions {
    my $self = shift;
    $self->{invindex}->file_exists("$self->{seg_name}.del");
}

sub _open_norms {
    my $self = shift;
    my ( $seg_name, $finfos, $comp_file_reader )
        = @{$self}{ 'seg_name', 'finfos', 'comp_file_reader' };
    my $max_doc = $self->max_doc;

    # create a NormsReader for each indexed field.
    for my $orig_num ( 0 .. $finfos->size - 1 ) {
        my $finfo = $finfos->info_by_orig_num($orig_num);
        next unless $finfo->get_indexed;
        my $instream
            = $comp_file_reader->open_instream("$seg_name.f$orig_num");
        $self->{norms_readers}{ $finfo->get_name }
            = KinoSearch::Index::NormsReader->new(
            instream => $instream,
            max_doc  => $max_doc,
            );
    }
}

sub terms {
    my ( $self, $term ) = @_;
    return $self->{tinfos_reader}->terms($term);
}

sub fetch_term_info {
    my ( $self, $term ) = @_;
    return $self->{tinfos_reader}->fetch_term_info($term);
}

sub doc_freq {
    my ( $self, $term ) = @_;
    my $tinfo = $self->{tinfos_reader}->fetch_term_info($term);
    return defined $tinfo ? $tinfo->get_doc_freq : 0;
}

sub term_docs {
    my ( $self, $term ) = @_;
    my $term_docs = KinoSearch::Index::SegTermDocs->new( reader => $self, );
    $term_docs->seek($term);
    return $term_docs;
}

sub norms_reader {
    my ( $self, $field_name ) = @_;
    return $self->{norms_readers}{$field_name};
}

sub get_field_names {
    my ( $self, %args ) = @_;
    my @fields = $self->{finfos}->get_infos;
    @fields = grep { $_->get_indexed } @fields
        if $args{indexed};
    my @names = map { $_->get_name } @fields;
    return \@names;
}

sub fetch_doc {
    $_[0]->{fields_reader}->fetch_doc( $_[1] );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::SegReader - read from a single-segment invindex

=head1 DESCRIPTION

Single-segment implementation of IndexReader.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut

