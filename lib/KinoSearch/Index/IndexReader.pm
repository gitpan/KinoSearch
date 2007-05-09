use strict;
use warnings;

package KinoSearch::Index::IndexReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    invindex     => undef,
    seg_infos    => undef,
    lock_factory => undef,

    # members
    sort_caches => {},
    lex_caches  => {},
    read_lock   => undef,
    commit_lock => undef,
);

BEGIN {
    __PACKAGE__->ready_get(qw( invindex ));
    __PACKAGE__->ready_get_set(qw( lock_factory read_lock ));
}

# test code will define these as coderefs
our $debug1;
our $debug2;

use KinoSearch::Index::IndexFileNames qw(
    COMMIT_LOCK_NAME
    COMMIT_LOCK_TIMEOUT
    READ_LOCK_TIMEOUT
    gen_from_filename
);
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegReader;
use KinoSearch::Index::MultiReader;
use KinoSearch::Index::MultiLexicon;
use KinoSearch::Index::PostingList;
use KinoSearch::Index::SegLexicon;
use KinoSearch::Index::LexCache;
use KinoSearch::Util::IntMap;
use KinoSearch::Store::Lock;

sub new { shift->abstract_death }

sub open {
    my $temp = shift->SUPER::new(@_);
    return $temp->_open_multi_or_segreader;
}

# Returns a subclass of IndexReader: either a MultiReader or a SegReader,
# depending on whether an InvIndex contains more than one segment.
sub _open_multi_or_segreader {
    my $self = shift;

    # verify InvIndex and extract schema
    my $invindex = $self->{invindex};
    confess("Missing required arg 'invindex'")
        unless a_isa_b( $invindex, "KinoSearch::InvIndex" );
    my $schema = $invindex->get_schema;
    my $folder = $invindex->get_folder;

    # confirm lock factory if supplied
    if ( defined $self->{lock_factory} ) {
        confess("Not a KinoSearch::Store::LockFactory")
            unless a_isa_b( $self->{lock_factory},
            "KinoSearch::Store::LockFactory" );
    }

    $self->_obtain_commit_lock if defined $self->{lock_factory};

    my $seg_infos;
    my @seg_readers;
    my ( $gen, $last_gen );
    while (1) {
        eval {
            # find the most recent segments file
            my $most_recent_segs_file
                = $folder->latest_gen( "segments", "yaml" );
            confess("Index doesn't seem to contain any data")
                unless defined $most_recent_segs_file;
            $gen = gen_from_filename($most_recent_segs_file);

            # get a read lock on the most recent segments file if indicated
            if ( defined $self->{lock_factory} ) {
                $self->_obtain_read_lock($most_recent_segs_file);
            }

            $debug1->() if defined $debug1;

            if ( defined $self->{seg_infos} ) {
                # either use the passed-in seg_infos...
                $seg_infos = $self->{seg_infos};
            }
            else {
                # ... or read the most recent segments file
                $seg_infos
                    = KinoSearch::Index::SegInfos->new( schema => $schema );
                my $folder = $invindex->get_folder;
                $seg_infos->read_infos( folder => $folder );
            }

            # throw an error if index doesn't exist
            confess("Index doesn't seem to contain any data")
                unless $seg_infos->size;

            # deal with race condition between locking and reading segs file
            if ( $seg_infos->get_generation > $gen ) {
                confess("More recent segs file than $gen detected");
            }

            for my $seg_info ( $seg_infos->infos ) {
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
        # we've got SegReaders holding open all the required files.  If we
        # failed to open something, see if we can find a newer segments file.
        # If we can, then the exception was due to the race condition.  If
        # not, we have a real exception, so throw an error.
        if ($@) {
            my $saved_error = $@;
            $self->_release_read_lock;
            if ( !defined $seg_infos
                or ( defined $last_gen and $last_gen == $gen ) )
            {
                $self->_release_commit_lock if defined $self->{lock_factory};
                confess($saved_error);
            }
            $last_gen    = $gen;
            @seg_readers = ();
            undef $seg_infos;
        }
        else {
            $self->{seg_infos} ||= $seg_infos;
            last;
        }
    }

    $self->_release_commit_lock if defined $self->{lock_factory};

    # if there's one SegReader use it; otherwise make a MultiReader
    my $true_self;
    if ( @seg_readers == 1 ) {
        $true_self = $seg_readers[0];
    }
    else {
        $true_self = KinoSearch::Index::MultiReader->new(
            invindex    => $invindex,
            sub_readers => \@seg_readers,
        );
    }

    # copy crucial elements
    $true_self->set_lock_factory( $self->{lock_factory} );
    $true_self->set_read_lock( $self->{read_lock} );

    # thwart release of lock on destruction of temp self
    undef $self->{read_lock};
    undef $self->{commit_lock};
    undef $self->{lock_factory};

    return $true_self;
}

sub DESTROY {
    my $self = shift;
    $self->_release_commit_lock if defined $self->{lock_factory};
    $self->_release_read_lock   if defined $self->{lock_factory};
}

sub _release_commit_lock {
    my $self = shift;
    if ( defined $self->{commit_lock} ) {
        $self->{commit_lock}->release;
        undef $self->{commit_lock};
    }
}

sub _release_read_lock {
    my $self = shift;
    if ( defined $self->{read_lock} ) {
        $self->{read_lock}->release;
        undef $self->{read_lock};
    }
}

sub _obtain_read_lock {
    my ( $self, $segs_file_name ) = @_;
    $segs_file_name =~ /^(segments_\w+)\.yaml$/
        or confess("no match: '$segs_file_name'");
    my $read_lock = $self->{lock_factory}->make_shared_lock(
        lock_name => $1,
        timeout   => READ_LOCK_TIMEOUT,
    );
    $read_lock->clear_stale;

    if ( $read_lock->obtain ) {
        $self->{read_lock} = $read_lock;
    }
    else {
        confess("Couldn't get read lock");
    }
}

sub _obtain_commit_lock {
    my $self        = shift;
    my $commit_lock = $self->{lock_factory}->make_lock(
        lock_name => COMMIT_LOCK_NAME,
        timeout   => COMMIT_LOCK_TIMEOUT,
    );
    $commit_lock->clear_stale;

    if ( $commit_lock->obtain ) {
        $self->{commit_lock} = $commit_lock;
    }
    else {
        confess("Couldn't get commit lock");
    }
}

=begin comment

    my $num = $reader->max_doc;

Return the highest document number available to the reader.

=end comment
=cut

sub max_doc { shift->abstract_death }

=begin comment

    my $num = $reader->num_docs;

Return the number of (non-deleted) documents available to the reader.

=end comment
=cut

sub num_docs { shift->abstract_death }

=begin comment

    # either or...
    $plist = $reader->posting_list( term  => $term );
    $plist = $reader->posting_list( field => $field );

Given either a Term or a field name, return a PostingList subclass.

=end comment
=cut

sub posting_list { shift->abstract_death }

=begin comment

    $reader->delete_docs_by_term( $term );

Delete all the documents available to the reader that index the given Term.

=end comment
=cut

sub delete_docs_by_term { shift->abstract_death }

=begin comment

    $boolean = $reader->has_deletions

Return true if any documents have been marked as deleted.

=end comment
=cut

sub has_deletions { shift->abstract_death }

=begin comment

    my $lexicon = $reader->look_up_term($term);

Given a Term, return a Lexicon subclass.  The list will be be pre-located via
$list->seek($term) to the right spot.

Returns undef if the term's field can't be found.

=end comment
=cut

sub look_up_term { shift->abstract_death }

=begin comment

    my $enum = $reader->look_up_field($field_name);

Very similar to look_up_term(), but seeks the Lexicon to the first term in the
field.

=end comment
=cut

sub look_up_field { shift->abstract_death }

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

        my $lexicon = $self->look_up_field($field_name);
        if ( defined $lexicon ) {
            $self->{sort_caches}{$field_name} = $lexicon->build_sort_cache(
                max_doc      => $self->max_doc,
                posting_list => $self->posting_list( field => $field_name ),
            );
            if ( $lexicon->can('get_lex_cache') ) {
                $self->{lex_caches}{$field_name} = $lexicon->get_lex_cache;
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

    my @sparse_segreaders = $reader->segreaders_to_merge;
    my @all_segreaders    = $reader->segreaders_to_merge('all');

Find segments which are good candidates for merging, as they don't contain
many valid documents.  Returns an array of SegReaders.  If passed an argument,
return all SegReaders.

=end comment
=cut

sub segreaders_to_merge { shift->abstract_death }

=begin comment

    my $seg_starts = $reader->get_seg_starts;

Returns a VArray of Ints, one for each segment, with integer value
corresponding to segment doc_num start offset.

=end comment
=cut

sub get_seg_starts { shift->abstract_death }

# Return the schema instance used by this reader's InvIndex.
sub get_schema { shift->get_invindex->get_schema }

=begin comment

    $reader->close;

Release all resources.

=end comment
=cut

sub close {
    my $self = shift;
    $self->_release_read_lock if defined $self->{lock_factory};
}

1;

__END__

=head1 NAME

KinoSearch::Index::IndexReader - Read from an inverted index.

=head1 SYNOPSIS

    my $reader = KinoSearch::Index::IndexReader->open(
        invindex => MySchema->open('/path/to/invindex'),
    );

=head1 DESCRIPTION

IndexReader is the interface through which Searchers access the content of an
L<InvIndex|KinoSearch::InvIndex>.

=head2 Point-in-time view of the invindex

IndexReader objects always represent a snapshot of an invindex as it existed
at the moment the reader was created.  If you want the search results to
reflect modifications to an InvIndex, you must create a new IndexReader after
the update process completes.

=head2 Caching a Searcher/Reader

When a IndexReader is created, a small portion of the InvIndex is loaded into
memory; additional sort caches are filled as relevant queries arrive.  For
large document collections, the warmup time may become noticable, in which
case reusing the reader is likely to speed up your search application.  

Caching an IndexReader (or a Searcher which contains an IndexReader) is
especially helpful when running a high-activity app in a persistent
environment, as under mod_perl or FastCGI.

=head2 Read-locking on shared volumes

When a file is no longer in use by an index, InvIndexer attempts to delete it
as part of a cleanup routine triggered by the call to finish().  It is
possible that at the moment an InvIndexer attempts to delete files that it no
longer thinks are needed, a Searcher is in fact using them.  This is
particularly likely in a persistent environment, where Searchers/IndexReaders
are cached and reused.  

Ordinarily, this is not is not a problem.

On a typical Unix volume, the file will be deleted in name only: any process
which holds an open filehandle against that file will continue to have access,
and the file won't actually get vaporized until the last filehandle is
cleared.  Thanks to "delete on last close semantics", an InvIndexer can't
truly delete the file out from underneath an active Searcher.  

On Windows, KinoSearch will attempt the file deletion, but an error will occur
if any process holds an open handle.  That's fine; InvIndexer runs these
unlink() calls within an eval block, and if the attempt fails it will just try
again the next time around.

On NFS, however, the system breaks, because NFS allows files to be deleted out
from underneath an active process.  Should this happen, the unlucky
IndexReader will crash with a "Stale NFS filehandle" exception.

Under normal circumstances, it is neither necessary nor desirable for
IndexReaders to secure read locks against an index, but for NFS we have to
make an exception.  L<KinoSearch::Store::LockFactory> exists for this reason;
supplying a LockFactory instance to IndexReader's constructor activates an
internal locking mechanism and prevents concurrent indexing processes from
deleting files that are needed by active readers.

LockFactory is implemented using lockfiles located in the index directory, so
your reader applications must have write access.  Stale lock files from
crashed processes are ordinarily cleared away the next time the same machine
-- as identified by the C<agent_id> parameter supplied to LockFactory's
constrctor -- opens another IndexReader. (The classic technique of timing out
lock files does not work because search processes may lie dormant
indefinitely.) However, please be aware that if the last thing a given machine
does is crash, lock files belonging to it may persist, preventing deletion of
obsolete index data.

=head1 FACTORY METHODS 

=head2 open

    my $reader = KinoSearch::Index::IndexReader->open(
        invindex     => MySchema->open('/path/to/invindex'),
        lock_factory => $lock_factory,
    );

IndexReader is an abstract base class; open() functions like a constructor,
but actually returns one of two possible subclasses: SegReader, which reads a
single segment, and MultiReader, which channels the output of several
SegReaders.  Since each segment is a self-contained inverted index, a
SegReader is in effect a complete index reader.  

open() takes labeled parameters.

=over 

=item *

B<invindex> - An object which isa L<KinoSearch::InvIndex>.

=item *

B<lock_factory> - An object which isa L<KinoSearch::Store::LockFactory>.
Read-locking is off by default; supplying C<lock_factory> turns it on.

=back

=head1 METHODS

=head2 max_doc

    my $max_doc = $reader->max_doc;

Returns one greater than the maximum document number in the invindex.  

=head2 num_docs

    my $docs_available = $reader->num_docs;

Returns the number of documents currently accessible.  Equivalent to max_doc()
minus deletions.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut

