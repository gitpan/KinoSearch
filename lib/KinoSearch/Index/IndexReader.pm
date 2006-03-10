package KinoSearch::Index::IndexReader;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Store::FSInvIndex;
use KinoSearch::Index::SegReader;
use KinoSearch::Index::MultiReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::IndexFileNames qw(
    WRITE_LOCK_NAME  WRITE_LOCK_TIMEOUT
    COMMIT_LOCK_NAME COMMIT_LOCK_TIMEOUT
);

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    invindex       => undef,
    seg_infos      => undef,
    close_invindex => 0,
    invindex_owner => 0,

    #    write_lock     => undef,
    #    stale          => 0,
    #    has_changes    => 0,
);

sub new {
    my $temp = shift->SUPER::new(@_);
    return $temp->_open_multi_or_segreader;
}

# Returns a subclass of IndexReader: either a MultiReader or a SegReader,
# depending on whether an invindex contains more than one segment.
sub _open_multi_or_segreader {
    my $self = shift;

    # confirm an InvIndex object or make one using a supplied filepath.
    if ( !a_isa_b( $self->{invindex}, 'KinoSearch::Store::InvIndex' ) ) {
        $self->{invindex}
            = KinoSearch::Store::FSInvIndex->new( path => $self->{invindex} );
    }
    my $invindex = $self->{invindex};

    # read the segments file and decide what to do
    my $reader;
    $invindex->run_while_locked(
        lock_name => COMMIT_LOCK_NAME,
        timeout   => COMMIT_LOCK_TIMEOUT,
        do_body   => sub {
            my $seg_infos = KinoSearch::Index::SegInfos->new;
            $seg_infos->read_infos($invindex);

            # create a SegReader for each segment in the invindex
            my @seg_readers;
            for ( 0 .. $seg_infos->size - 1 ) {
                my $sinfo = $seg_infos->info($_);
                push @seg_readers,
                    KinoSearch::Index::SegReader->new(
                    seg_name => $sinfo->{seg_name},
                    invindex => $invindex,
                    );
            }
            # if there's one SegReader use it; otherwise make a MultiReader
            $reader =
                  @seg_readers == 1
                ? $seg_readers[0]
                : KinoSearch::Index::MultiReader->new(
                invindex    => $invindex,
                sub_readers => \@seg_readers,
                );
        },
    );

    return $reader;
}

sub get_invindex { shift->{invindex} }

=begin comment

    my $num = $reader->max_doc;

Return the highest document number available to the reader

=end comment
=cut

sub max_doc { shift->abstract_death }

=begin comment

    my $term_docs = $reader->term_docs($term);

Given a Term, return a TermDocs subclass.

=end comment
=cut

sub term_docs { shift->abstract_death }

=begin comment

    my $norms_reader = $reader->norms_reader($field_name);

Given a field name, return a NormsReader object.

=end comment
=cut

sub norms_reader { shift->abstract_death }

=begin comment

    $boolean = $reader->has_deletions

Return true if any documents have been marked as deleted.

=end comment
=cut

sub has_deletions { shift->abstract_death }

=begin comment

    my $enum = $reader->terms($term);

Given a Term, return a TermEnum subclass.  The Enum will be be pre-located via
$enum->seek($term) to the right spot.

=end comment
=cut

sub terms { shift->abstract_death }

=begin comment

    my $field_names = $reader->get_field_names(
        indexed => $indexed_fields_only,
    );

Return a hashref which is a list of field names.  If the parameter 'indexed'
is true, return only the names of fields which are indexed.

=end comment
=cut

sub get_field_names { shift->abstract_death }

=begin comment

    $reader->do_close;

Release any necessary resources. Called by close().

=end comment
=cut

sub do_close { shift->abstract_death }

sub close {
    my $self = shift;
    $self->do_close;
    $self->{invindex}->close
        if ( $self->{close_invindex} );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::IndexReader - base class for objects which read invindexes

=head1 DESCRIPTION

There are two subclasses of the abstract base class IndexReader: SegReader,
which reads a single segment, and MultiReader, which condenses the output of
several SegReaders.  Since each segment is a self-contained inverted index, a
SegReader is in effect a complete index reader.  

The constructor for IndexReader returns either a SegReader if the index has
only one segment, or a MultiReader if there are multiple segments.

=head1 TODO

Consider eliminating this abstract base class and turning MultiReader into
IndexReader.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut

