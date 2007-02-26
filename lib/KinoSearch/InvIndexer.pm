use strict;
use warnings;

package KinoSearch::InvIndexer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args / members
        invindex => undef,
        lock_id  => '',

        # members
        schema        => undef,
        folder        => undef,
        seg_info      => undef,
        ix_reader     => undef,
        seg_infos     => undef,
        seg_writer    => undef,
        write_lock    => undef,
        utf8_fields   => {},
        has_deletions => 0,
    );
}

use KinoSearch::Index::IndexReader;
use KinoSearch::Index::SegInfo;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegWriter;
use KinoSearch::Index::IndexFileNames
    qw( WRITE_LOCK_NAME WRITE_LOCK_TIMEOUT unused_files );
use KinoSearch::Util::StringHelper qw( to_base36 );

sub init_instance {
    my $self = shift;

    # confirm invindex and extract schema and Folder
    my $invindex = $self->{invindex};
    confess("Missing required arg 'invindex'")
        unless a_isa_b( $invindex, "KinoSearch::InvIndex" );
    my $folder = $self->{folder} = $invindex->get_folder;
    my $schema = $self->{schema} = $invindex->get_schema;

    # get a write lock for this folder.
    my $write_lock = $folder->make_lock(
        lock_name => WRITE_LOCK_NAME,
        timeout   => WRITE_LOCK_TIMEOUT,
        lock_id   => $self->{lock_id},
    );
    if ( $write_lock->obtain ) {
        # only assign if successful, otherwise DESTROY unlocks (bad!)
        $self->{write_lock} = $write_lock;
    }
    else {
        confess( "folder locked: " . $write_lock->get_lock_name );
    }

    # read the segment infos
    my $seg_infos = $self->{seg_infos} = KinoSearch::Index::SegInfos->new;
    $seg_infos->read_infos($folder);

    # get an IndexReader if the invindex already has content
    if ( $seg_infos->size ) {
        $self->{ix_reader} = KinoSearch::Index::IndexReader->new(
            invindex  => $invindex,
            seg_infos => $seg_infos,
        );
    }

    # name a new segment, create a SegInfo and a SegWriter
    my $seg_name = $self->_new_seg_name;
    my $seg_info = $self->{seg_info} = KinoSearch::Index::SegInfo->new(
        seg_name => $seg_name,
        fspecs   => $schema->get_fspecs,
    );
    $self->{seg_writer} = KinoSearch::Index::SegWriter->new(
        invindex => $invindex,
        seg_info => $seg_info,
    );

    # cache names of fields for which utf8 verification is necessary
    for my $field_spec ( $schema->all_fspecs ) {
        next if $field_spec->binary;
        $self->{utf8_fields}{ $field_spec->get_name } = 1;
    }
}

my %add_doc_args = ( boost => undef, );

sub add_doc {
    my $self = shift;
    my $doc  = shift;
    confess("First argument must be a hashref")
        unless reftype($doc) eq 'HASH';
    confess kerror() unless verify_args( \%add_doc_args, @_ );
    my %args        = @_;
    my $utf8_fields = $self->{utf8_fields};

    for my $field_name ( keys %$doc ) {
        next unless $utf8_fields->{$field_name};
        utf8::upgrade( $doc->{$field_name} );
    }

    # add doc to output segment
    my $boost = defined $args{boost} ? $args{boost} : 1.0;
    $self->{seg_writer}->add_doc( $doc, $boost );
}

sub add_invindexes {
    my ( $self, @invindexes ) = @_;

    # all the invindexes must match our schema
    my $orig_class = ref( $self->{schema} );
    for (@invindexes) {
        my $other_class = ref( $_->get_schema );
        next if $other_class eq $orig_class;
        confess("Schema subclass '$other_class' doesn't match $orig_class");
    }

    # get an ix_reader for each InvIndex
    my @ix_readers
        = map { KinoSearch::Index::IndexReader->new( invindex => $_ ) }
        @invindexes;

    # add all segments in each of the supplied invindexes
    my $seg_writer = $self->{seg_writer};
    for my $ix_reader (@ix_readers) {
        $seg_writer->add_segment($_)
            for $ix_reader->segreaders_to_merge('all');
    }
}

sub delete_docs_by_term {
    confess(  "delete_docs_by_term() has been replaced by delete_by_term(), "
            . "which has slightly different behavior -- see InvIndexer's docs"
    );
}

sub delete_by_term {
    my ( $self, $field_name, $term_text ) = @_;

    # bail if this is a new InvIndex
    return unless $self->{ix_reader};

    # raise exception if the field isn't indexed
    my $field_spec = $self->{schema}->fetch_fspec($field_name);
    confess("$field_name is not an indexed field")
        unless ( defined $field_spec and $field_spec->indexed );

    # create a term, analyze it, and ask the ix_reader to delete docs with it
    my $term;
    if ( $field_spec->analyzed ) {
        my $analyzer = $self->{schema}->fetch_analyzer($field_name);
        my ($analyzed_text) = $analyzer->analyze_raw($term_text);
        $term = KinoSearch::Index::Term->new( $field_name, $analyzed_text );
    }
    else {
        $term = KinoSearch::Index::Term->new( $field_name, $term_text );
    }
    $self->{ix_reader}->delete_docs_by_term($term);

    # trigger write later
    $self->{has_deletions} = 1;
}

our %finish_defaults = ( optimize => 0 );

sub finish {
    my $self = shift;
    confess kerror() unless verify_args( \%finish_defaults, @_ );
    my %args = ( %finish_defaults, @_ );
    my ( $folder, $seg_info, $seg_infos, $seg_writer, $ix_reader )
        = @{$self}{qw( folder seg_info seg_infos seg_writer ix_reader )};

    # safety check
    if ( !defined $self->{write_lock} ) {
        confess("Can't call finish() more than once");
    }

    # perform segment merging
    my @to_merge = $ix_reader
        ? $ix_reader->segreaders_to_merge( $args{optimize} )
        : ();
    $seg_writer->add_segment($_)                   for @to_merge;
    $seg_infos->delete_segment( $_->get_seg_name ) for @to_merge;

    # write out new deletions
    $self->{ix_reader}->write_deletions if $self->{has_deletions};

    # if docs were added, write a new segment
    if ( $seg_info->get_doc_count or @to_merge ) {
        # finish the segment and add its info to the 'segments' file
        $seg_writer->finish;
        $seg_infos->add_info( $seg_writer->get_seg_info );
    }

    # write a new segments_XXX.yaml file if anything has changed
    if (   $seg_info->get_doc_count
        or $self->{has_deletions}
        or @to_merge )
    {
        $seg_infos->write_infos($folder);
    }

    # close ix_reader, so that we can delete its files if appropriate
    $ix_reader->close if defined $ix_reader;

    # purge obsolete files
    my @file_list = $folder->list;
    my @files_to_delete = unused_files( \@file_list, $seg_infos );
    $self->_purge_unused(@files_to_delete);

    # realease the write lock, invalidating the invindexer
    $self->_release_locks;
}

# Delete unused files.
sub _purge_unused {
    my ( $self, @deletions ) = @_;
    my $folder = $self->{folder};

    # attempt to delete files -- if failure, no big deal, try again later
    for my $deletion (@deletions) {
        eval { $folder->delete_file($deletion) };
    }
}

# Release the write lock - if it's there.
sub _release_locks {
    my $self = shift;
    if ( defined $self->{write_lock} ) {
        $self->{write_lock}->release if $self->{write_lock}->is_locked;
        undef $self->{write_lock};
    }
}

# Generate segment names.
sub _new_seg_name {
    my $self = shift;

    my $counter = $self->{seg_infos}->get_seg_counter;
    $self->{seg_infos}->set_seg_counter( ++$counter );

    return '_' . to_base36($counter);
}

sub DESTROY { shift->_release_locks }

1;

__END__

=head1 NAME

KinoSearch::InvIndexer - Build inverted indexes.

=head1 SYNOPSIS

    use KinoSearch::InvIndexer;
    use MySchema;

    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => MySchema->clobber('/path/to/invindex'),
    );

    while ( my ( $title, $content ) = each %source_docs ) {
        $invindexer->add_doc({
            title   => $title,
            content => $content,
        });
    }

    $invindexer->finish;

=head1 DESCRIPTION

The InvIndexer class is KinoSearch's primary tool for managing the content of
inverted indexes, which may later be searched using L<KinoSearch::Searcher>.

=head2 Concurrency

Only one InvIndexer may write to an invindex at a time.  If a write lock
cannot be secured, new() will throw an exception.

Indexes shared among multiple machines require special handling.  First, be
sure to read L<KinoSearch::Docs::NFS> if you are considering locating an index
on an NFS volume.  Second, it is essential that every machine writing to a
shared index identify itself with a unique C<lock_id>, or the locking
mechanism will malfunction.

=head1 METHODS

=head2 new

    my $invindex = MySchema->clobber('/path/to/invindex');
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex    => $invindex,  # required
        lock_id     => $hostname   # default: ''
    );

Constructor.  Takes labeled parameters.

=over

=item *

B<invindex> - An object of type L<KinoSearch::InvIndex>.

=item *

B<lock_id> - a string which differentiates this machine from others which
may try to write to the same invindex.

=back

=head2 add_doc

    $invindexer->add_doc( { field_name => $field_value } );
    # or ...
    $invindexer->add_doc( { field_name => $field_value }, boost => 2.5 );

Add a document to the invindex.  The first argument must be a reference to hash
comprised of field_name => field_value pairs.  Ownership of the hash is assumed
by the InvIndexer object.  

After the hashref, labeled parameters are accepted.

=over

=item *

<boost> - A scoring multiplier.  Setting boost to something other than 1
causes a document to score better or worse against a given query relative to
other documents. 

=back

=head2 add_invindexes

    $invindexer->add_invindexes( $another_invindex, $yet_another_invindex );

Absorb existing invindexes into this one.  The other invindexes must use the
same Schema as the invindex which was supplied to new().

=head2 delete_by_term

    $invindexer->delete_by_term( $field_name, $term_text );

Mark documents which contains the supplied term as deleted, so that they will
be excluded from search results.  The change is not apparent to search apps
until a new Searcher is opened I<after> finish() completes.

If the field is associated with an analyzer, C<$term_text> will be
processed automatically (so don't process it yourself).

C<$field_name>  must identify an I<indexed> field, or an error will occur.

=head2 finish 

    $invindexer->finish( 
        optimize => 1, # default: 0
    );

Finish processing any changes made to the invindex and commit.  Until the
commit happens near the end of the finish(), none of the changes made during
an indexing session are permanent.

Calling finish() invalidates the InvIndexer, so if you want to make more
changes you'll need a new one.

Takes one labeled parameter:

=over

=item *

B<optimize> - If optimize is set to 1, the invindex will be collapsed to its
most compact form, a process which may take a while -- but which will yield
the fastest queries at search time.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut
