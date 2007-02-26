use strict;
use warnings;

package KinoSearch::Index::IndexReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        invindex  => undef,
        seg_infos => undef,

        # members
        tl_caches => {},
    );
    __PACKAGE__->ready_get(qw( invindex ));
}
our %instance_vars;

use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegReader;
use KinoSearch::Index::MultiReader;
use KinoSearch::Index::MultiTermList;
use KinoSearch::Index::SegTermList;
use KinoSearch::Index::TermListCache;
use KinoSearch::Util::IntMap;

sub new {
    my $temp = shift->SUPER::new(@_);
    return $temp->_open_multi_or_segreader;
}

# Returns a subclass of IndexReader: either a MultiReader or a SegReader,
# depending on whether an InvIndex contains more than one segment.
sub _open_multi_or_segreader {
    my $self = shift;

    # verify InvIndex
    my $invindex = $self->{invindex};
    confess("Missing required arg 'invindex'")
        unless a_isa_b( $invindex, "KinoSearch::InvIndex" );

    my $seg_infos;
    if ( defined $self->{seg_infos} ) {
        # either use the passed-in seg_infos...
        $seg_infos = $self->{seg_infos};
    }
    else {
        # ... or read the most recent segments file
        $seg_infos = KinoSearch::Index::SegInfos->new;
        my $folder = $invindex->get_folder;
        $seg_infos->read_infos($folder);
    }

    # throw an error if index doesn't exist
    confess("Index doesn't seem to contain any data") unless $seg_infos->size;

    my @seg_readers;
    while (1) {
        eval {
            for my $seg_info ( $seg_infos->infos )
            {
                # create a SegReader for each segment in the InvIndex
                push @seg_readers,
                    KinoSearch::Index::SegReader->new(
                    invindex => $invindex,
                    seg_info => $seg_info,
                    );
            }
        };

        # It's possible, though unlikely, for an InvIndexer to delete files
        # out from underneath us after the segments file is read but before
        # we've got a SegReader holding open all the required files.  If we
        # failed to open something, see if we can find a newer segments file.
        # If we can, then the exception was due to the race condition.  If
        # not, we have a real exception, so throw an error.
        last unless $@;
        my $saved_error = $@;
        my $gen         = $seg_infos->get_generation;
        $seg_infos = KinoSearch::Index::SegInfos->new;
        $seg_infos->read_infos( $invindex->get_folder );
        if ( $seg_infos->get_generation == $gen ) {
            confess($saved_error);
        }
        @seg_readers = ();
    }

    # if there's one SegReader use it; otherwise make a MultiReader
    if ( @seg_readers == 1 ) {
        return $seg_readers[0];
    }
    else {
        return KinoSearch::Index::MultiReader->new(
            invindex    => $invindex,
            sub_readers => \@seg_readers,
        );
    }
}

=begin comment

    my $num = $ix_reader->max_doc;

Return the highest document number available to the ix_reader.

=end comment
=cut

sub max_doc { shift->abstract_death }

=begin comment

    my $num = $ix_reader->num_docs;

Return the number of (non-deleted) documents available to the ix_reader.

=end comment
=cut

sub num_docs { shift->abstract_death }

=begin comment

    my $term_docs = $ix_reader->term_docs($term);

Given a Term, return a TermDocs subclass.

=end comment
=cut

sub term_docs { shift->abstract_death }

=begin comment

    $ix_reader->delete_docs_by_term( $term );

Delete all the documents available to the ix_reader that index the given Term.

=end comment
=cut

sub delete_docs_by_term { shift->abstract_death }

=begin comment

    $boolean = $ix_reader->has_deletions

Return true if any documents have been marked as deleted.

=end comment
=cut

sub has_deletions { shift->abstract_death }

=begin comment

    my $term_list = $ix_reader->field_terms($term);

Given a Term, return a TermList subclass.  The list will be be pre-located via
$list->seek($term) to the right spot.

Returns undef if the term's field can't be found.

=end comment
=cut

sub field_terms { shift->abstract_death }

=begin comment

    my $enum = $ix_reader->start_field_terms($field_name);

Very similar to field_terms(), but seeks the TermList to the first term in the
field.

=end comment
=cut

#sub field_terms { shift->abstract_death }
sub start_field_terms {
    my ( $self, $field_name ) = @_;
    my $term = KinoSearch::Index::Term->new( $field_name, "" );
    return $self->field_terms($term);
}

# Return an IntMap sort cache for the given field.
sub fetch_sort_cache {
    my ( $self, $field_name ) = @_;

    # cache the cache
    if ( !exists $self->{sort_caches}{$field_name} ) {

        # enforce 1 value per field
        my $field_spec
            = $self->{invindex}->get_schema->fetch_fspec($field_name);
        confess("'$field_name' is not an indexed, un-analyzed field")
            unless ( defined $field_spec
            and $field_spec->indexed
            and !$field_spec->analyzed );

        my $term_list = $self->start_field_terms($field_name);
        if ( defined $term_list ) {
            $self->{sort_caches}{$field_name} = $term_list->build_sort_cache(
                max_doc   => $self->max_doc,
                term_docs => $self->term_docs,
            );
            if ($term_list->can('get_tl_cache') ) {
                $self->{tl_caches}{$field_name} = $term_list->get_tl_cache;
            }
        }
        else {
            # get an empty IntMap if this field has no values
            $self->{sort_caches}{$field_name}
                = KinoSearch::Util::IntMap->new( ints => "", );
        }
    }

    return $self->{sort_caches}{$field_name};
}

=begin comment

    my @sparse_segreaders = $ix_reader->segreaders_to_merge;
    my @all_segreaders    = $ix_reader->segreaders_to_merge('all');

Find segments which are good candidates for merging, as they don't contain
many valid documents.  Returns an array of SegReaders.  If passed an argument,
return all SegReaders.

=end comment
=cut

sub segreaders_to_merge { shift->abstract_death }

=begin comment

Return an arrayref of SegSearchers, one for each segment the IndexReader
contains.

    my $seg_searchers = $ix_reader->seg_searchers;

=end comment
=cut

sub seg_searchers { shift->abstract_death }

=begin comment

    $ix_reader->close;

Release all resources.

=end comment
=cut

sub close { shift->abstract_death }

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::IndexReader - Base class for objects which read invindexes.

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

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
