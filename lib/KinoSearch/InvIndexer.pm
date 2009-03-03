package KinoSearch::InvIndexer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use constant UNINITIALIZED => 0;
use constant INITIALIZED   => 1;
use constant FINISHED      => 2;

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args / members
        create   => undef,
        invindex => undef,
        analyzer => undef,

        # members
        reader       => undef,
        analyzers    => undef,
        sinfos       => undef,
        finfos       => undef,
        doc_template => undef,
        frozen_doc   => undef,
        similarity   => undef,
        field_sims   => undef,
        seg_writer   => undef,
        write_lock   => undef,
        state        => UNINITIALIZED,
    );
}

use Storable qw( freeze thaw );
use File::Spec::Functions qw( catfile tmpdir );

use KinoSearch::Document::Doc;
use KinoSearch::Document::Field;
use KinoSearch::Analysis::Analyzer;
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Index::FieldInfos;
use KinoSearch::Index::FieldsReader;
use KinoSearch::Index::IndexReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegWriter;
use KinoSearch::Index::IndexFileNames
    qw( WRITE_LOCK_NAME    COMMIT_LOCK_NAME
    WRITE_LOCK_TIMEOUT COMMIT_LOCK_TIMEOUT );
use KinoSearch::Search::Similarity;

sub init_instance {
    my $self = shift;
    $self->{analyzers}  = {};
    $self->{field_sims} = {};

    # use a no-op Analyzer if not supplied
    $self->{analyzer} ||= KinoSearch::Analysis::Analyzer->new;

    # create a few members
    $self->{similarity}   = KinoSearch::Search::Similarity->new;
    $self->{sinfos}       = KinoSearch::Index::SegInfos->new;
    $self->{doc_template} = KinoSearch::Document::Doc->new;

    # confirm or create an InvIndex object
    my $invindex;
    if ( blessed( $self->{invindex} )
        and $self->{invindex}->isa('KinoSearch::Store::InvIndex') )
    {
        $invindex = $self->{invindex};
        $self->{create} = $invindex->get_create
            unless defined $self->{create};
    }
    elsif ( defined $self->{invindex} ) {
        $invindex = $self->{invindex} = KinoSearch::Store::FSInvIndex->new(
            create => $self->{create},
            path   => $self->{invindex},
        );
    }
    else {
        croak("Required parameter 'invindex' not supplied");
    }

    # get a write lock for this invindex.
    my $write_lock = $invindex->make_lock(
        lock_name => WRITE_LOCK_NAME,
        timeout   => WRITE_LOCK_TIMEOUT,
    );
    if ( $write_lock->obtain ) {
        # only assign if successful, otherwise DESTROY unlocks (bad!)
        $self->{write_lock} = $write_lock;
    }
    else {
        croak( "invindex locked: " . $write_lock->get_lock_name );
    }

    # read/write SegInfos
    eval {
        $invindex->run_while_locked(
            lock_name => COMMIT_LOCK_NAME,
            timeout   => COMMIT_LOCK_TIMEOUT,
            do_body   => sub {
                $self->{create}
                    ? $self->{sinfos}->write_infos($invindex)
                    : $self->{sinfos}->read_infos($invindex);
            },
        );
    };
    if ($@) {
        $self->{create}
            ? croak("failed to create invindex: $@")
            : croak("failed to open existing invindex: $@");
    }

    # get a finfos and maybe a reader
    if ( $self->{create} ) {
        $self->{finfos} = KinoSearch::Index::FieldInfos->new;
    }
    else {
        $self->{reader}
            = KinoSearch::Index::IndexReader->new( invindex => $invindex );
        $self->{finfos} = $self->{reader}->generate_field_infos;
    }

    # more initialization is coming after fields are spec'd...
}

sub _delayed_init {
    my $self = shift;
    my ( $invindex, $finfos, $field_sims )
        = @{$self}{qw( invindex finfos field_sims )};

    confess("finish has been called")
        if $self->{state} == FINISHED;
    confess("internal error: already initialized")
        if $self->{state} == INITIALIZED;
    $self->{state} = INITIALIZED;

    # create a cloning template
    my $doc = $self->{doc_template};
    for my $field ( $doc->get_fields ) {
        $field->set_field_num( $finfos->get_field_num( $field->get_name ) );
    }
    $self->{frozen_doc} = freeze($doc);

    # set sim for each field
    my $main_sim = $self->{similarity};
    for my $finfo ( $finfos->get_infos ) {
        $field_sims->{ $finfo->get_name } ||= $main_sim;
    }

    # name a new segment and create a SegWriter
    my $out_seg_name = $self->_new_seg_name;
    $self->{seg_writer} = KinoSearch::Index::SegWriter->new(
        invindex   => $invindex,
        seg_name   => $out_seg_name,
        finfos     => $finfos->clone,
        field_sims => $field_sims,
    );
}

sub spec_field {
    my $self = shift;

    # don't allow new fields to be spec'd once the seg is in motion
    croak("Too late to spec field (new_doc has been called)")
        unless $self->{state} == UNINITIALIZED;

    # detect or define a Field object
    my $field;
    if ( blessed( $_[0] ) ) {
        $field = shift;
    }
    else {
        eval { $field = KinoSearch::Document::Field->new(@_) };
        croak $@ if $@;
    }

    # cache fnm_bits and fdt_bits
    $field->set_fnm_bits(
        KinoSearch::Index::FieldInfos->encode_fnm_bits($field) );
    $field->set_fdt_bits(
        KinoSearch::Index::FieldsReader->encode_fdt_bits($field) );

    # establish which analyzer will be used against the field
    $self->{analyzers}{ $field->get_name }
        = ( $field->get_analyzer || $self->{analyzer} );

    # don't copy the analyzer into the template, so that it can be overridden
    $field->set_analyzer(undef);

    # add the field to the finfos and the template.
    $self->{finfos}->add_field($field);
    $self->{doc_template}->add_field($field);
}

sub new_doc {
    my $self = shift;
    $self->_delayed_init unless $self->{state} == INITIALIZED;
    return thaw( $self->{frozen_doc} );
}

sub set_similarity {
    if ( @_ == 3 ) {
        my ( $self, $field_name, $sim ) = @_;
        $self->{field_sims}{$field_name} = $sim;
    }
    else {
        $_[0]->{similarity} = $_[1];
    }
}

sub add_doc {
    my ( $self, $doc ) = @_;

    # assign analyzers
    for my $field ( $doc->get_fields ) {
        if ( $field->get_analyzed ) {
            next if $field->get_analyzer;
            my $fieldname = $field->get_name;
            $field->set_analyzer( $self->{analyzers}{$fieldname} );
        }
    }

    # add doc to output segment
    $self->{seg_writer}->add_doc($doc);
}

sub add_invindexes {
    my ( $self, @invindexes ) = @_;
    confess("Can't call add_invindexes after new_doc")
        if $self->{state} == INITIALIZED;

    # verify or obtain InvIndex objects
    for (@invindexes) {
        if ( !a_isa_b( $_, 'KinoSearch::Store::InvIndex' ) ) {
            $_ = KinoSearch::Store::FSInvIndex->new( path => $_ );
        }
    }

    # get a reader for each invindex
    my @readers
        = map { KinoSearch::Index::IndexReader->new( invindex => $_ ) }
        @invindexes;

    # merge finfos and init
    for my $reader (@readers) {
        $self->{finfos}->consolidate( $reader->get_finfos );
    }
    $self->_delayed_init;

    # add all segments in each of the supplied invindexes
    my $seg_writer = $self->{seg_writer};
    for my $reader (@readers) {
        $seg_writer->add_segment($_) for $reader->segreaders_to_merge('all');
    }
}

sub delete_docs_by_term {
    my ( $self, $term ) = @_;
    confess("Not a KinoSearch::Index::Term")
        unless a_isa_b( $term, 'KinoSearch::Index::Term' );
    return               unless $self->{reader};
    $self->_delayed_init unless $self->{state} == INITIALIZED;
    $self->{reader}->delete_docs_by_term($term);

}

our %finish_defaults = ( optimize => 0, );

sub finish {
    my $self = shift;
    confess kerror() unless verify_args( \%finish_defaults, @_ );
    my %args = ( %finish_defaults, @_ );

    # if no changes were made to the index, don't write anything
    if ( $self->{state} == UNINITIALIZED ) {
        if ( !$args{optimize} ) {
            return;
        }
        else {
            $self->_delayed_init;
        }
    }

    my ( $invindex, $sinfos, $seg_writer )
        = @{$self}{qw( invindex sinfos seg_writer )};

    # perform segment merging
    my @to_merge =
          $self->{reader}
        ? $self->{reader}->segreaders_to_merge( $args{optimize} )
        : ();
    $seg_writer->add_segment($_)                for @to_merge;
    $sinfos->delete_segment( $_->get_seg_name ) for @to_merge;

    # finish the segment
    $seg_writer->finish;

    # now that the seg is complete, write its info to the 'segments' file
    my $doc_count = $seg_writer->get_doc_count;
    if ($doc_count) {
        $sinfos->add_info(
            KinoSearch::Index::SegInfo->new(
                seg_name  => $seg_writer->get_seg_name,
                doc_count => $doc_count,
                invindex  => $invindex,
            )
        );
    }

    # commit changes to the invindex
    $invindex->run_while_locked(
        lock_name => COMMIT_LOCK_NAME,
        timeout   => COMMIT_LOCK_TIMEOUT,
        do_body   => sub {
            $self->{reader}->commit_deletions if defined $self->{reader};
            $sinfos->write_infos($invindex);
        },
    );

    my @files_to_delete = $self->_generate_deletions_list( \@to_merge );
    push @files_to_delete, $self->_read_delqueue;

    # close reader, so that we can delete its files if appropriate
    $self->{reader}->close if defined $self->{reader};

    $self->_purge_merged(@files_to_delete);
    $self->_release_locks;
    $self->{state} = FINISHED;
}

# Given an array of SegReaders, return a list of their files.
sub _generate_deletions_list {
    my ( $self, $readers_to_merge ) = @_;
    my $invindex      = $self->{invindex};
    my @segs_to_merge = map { $_->get_seg_name } @$readers_to_merge;
    my @deletions     = grep { $invindex->file_exists($_) }
        map { ( "$_.cfs", "$_.del" ) } @segs_to_merge;
    return @deletions;
}

# Retrieve a list of files that weren't successfully deleted before.
sub _read_delqueue {
    my ( $self, $readers_to_merge ) = @_;
    my $invindex = $self->{invindex};
    my @deletions;

    if ( $invindex->file_exists('delqueue') ) {
        my $instream     = $invindex->open_instream('delqueue');
        my $num_in_queue = $instream->lu_read('i');
        @deletions = $instream->lu_read("T$num_in_queue");
        $instream->close;
    }

    return @deletions;
}

# Delete segments that have been folded into the new segment.
sub _purge_merged {
    my ( $self, @deletions ) = @_;
    my $invindex = $self->{invindex};

    my @delqueue;
    for my $deletion (@deletions) {
        eval { $invindex->delete_file($deletion) };
        # Win32: if the deletion fails (because a reader is open), queue it
        if ( $@ and $invindex->file_exists($deletion) ) {
            push @delqueue, $deletion;
        }
    }

    $self->_write_delqueue(@delqueue);
}

sub _write_delqueue {
    my ( $self, @delqueue ) = @_;
    my $invindex  = $self->{invindex};
    my $num_files = scalar @delqueue;

    if ($num_files) {
        # we have files that weren't successfully deleted, so write list
        my $outstream = $invindex->open_outstream('delqueue.new');
        $outstream->lu_write( "iT$num_files", $num_files, @delqueue );
        $outstream->close;
        $invindex->rename_file( 'delqueue.new', 'delqueue' );
    }
    elsif ( $invindex->file_exists('delqueue') ) {
        # no files to delete, so delete the delqueue file if it's there
        $invindex->delete_file('delqueue');
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

# Generate segment names (no longer Lucene compatible, as of 0.06).
sub _new_seg_name {
    my $self = shift;

    my $counter = $self->{sinfos}->get_counter;
    $self->{sinfos}->set_counter( ++$counter );

    return "_$counter";
}

sub DESTROY { shift->_release_locks }

1;

__END__

=head1 NAME

KinoSearch::InvIndexer - build inverted indexes

=head1 WARNING

KinoSearch is alpha test software.  The API and the file format are subject to
change.

=head1 SYNOPSIS

    use KinoSearch::InvIndexer;
    use KinoSearch::Analysis::PolyAnalyzer;

    my $analyzer
        = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );

    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => '/path/to/invindex',
        create   => 1,
        analyzer => $analyzer,
    );

    $invindexer->spec_field( 
        name  => 'title' 
        boost => 3,
    );
    $invindexer->spec_field( name => 'bodytext' );

    while ( my ( $title, $bodytext ) = each %source_documents ) {
        my $doc = $invindexer->new_doc($title);

        $doc->set_value( title    => $title );
        $doc->set_value( bodytext => $bodytext );

        $invindexer->add_doc($doc);
    }

    $invindexer->finish;

=head1 DESCRIPTION

The InvIndexer class is KinoSearch's primary tool for creating and
modifying inverted indexes, which may be searched using
L<KinoSearch::Searcher|KinoSearch::Searcher>.

=head1 METHODS

=head2 new

    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => '/path/to/invindex',  # required
        create   => 1,                    # default: 0
        analyzer => $analyzer,            # default: no-op Analyzer
    );

Create an InvIndexer object.  

=over

=item *

B<invindex> - can be either a filepath, or an InvIndex subclass such as
L<KinoSearch::Store::FSInvIndex|KinoSearch::Store::FSInvIndex> or 
L<KinoSearch::Store::RAMInvIndex|KinoSearch::Store::RAMInvIndex>.

=item *

B<create> - create a new invindex, clobbering an existing one if necessary.

=item *

B<analyzer> - an object which subclasses L<KinoSearch::Analysis::Analyzer>,
such as a L<PolyAnalyzer|KinoSearch::Analysis::PolyAnalyzer>.

=back

=head2 spec_field

    $invindexer->spec_field(
        name       => 'url',      # required
        boost      => 1,          # default: 1,
        analyzer   => undef,      # default: analyzer spec'd in new()
        indexed    => 0,          # default: 1
        analyzed   => 0,          # default: 1
        stored     => 1,          # default: 1
        compressed => 0,          # default: 0
        vectorized => 0,          # default: 1
    );

Define a field. 

=over

=item *

B<name> - the field's name.

=item *

B<boost> - A multiplier which determines how much a field contributes
to a document's score.  

=item *

B<analyzer> - By default, all indexed fields are analyzed using the analyzer
that was supplied to new().  Supplying an alternate for a given field
overrides the primary analyzer.

=item *

B<indexed> - index the field, so that it can be searched later.

=item *

B<analyzed> - analyze the field, using the relevant Analyzer.  Fields such as
"category" or "product_number" might be indexed but not analyzed.

=item *

B<stored> - store the field, so that it can be retrieved when the document
turns up in a search.

=item *

B<compressed> - compress the stored field, using the zlib compression algorithm.

=item *

B<vectorized> - store the field's "term vectors", which are required by
L<KinoSearch::Highlight::Highlighter|KinoSearch::Highlight::Highlighter> for
excerpt selection and search term highlighting.

=back

=head2 new_doc

    my $doc = $invindexer->new_doc;

Spawn an empty L<KinoSearch::Document::Doc|KinoSearch::Document::Doc> object,
primed to accept values for the fields spec'd by spec_field.

=head2 add_doc

    $invindexer->add_doc($doc);

Add a document to the invindex.

=head2 add_invindexes

    my $invindexer = KinoSearch::InvIndexer->new( 
        invindex => $invindex,
        analyzer => $analyzer,
    );
    $invindexer->add_invindexes( $another_invindex, $yet_another_invindex );
    $invindexer->finish;

Absorb existing invindexes into this one.  May only be called once per
InvIndexer.  add_invindexes() and add_doc() cannot be called on the same
InvIndexer.

=head2 delete_docs_by_term

    my $term = KinoSearch::Index::Term->new( 'id', $unique_id );
    $invindexer->delete_docs_by_term($term);

Mark any document which contains the supplied term as deleted, so that it will
be excluded from search results.  For more info, see
L<Deletions|KinoSearch::Docs::FileFormat/Deletions> in
KinoSearch::Docs::FileFormat.

=head2 finish 

    $invindexer->finish( 
        optimize => 1, # default: 0
    );

Finish the invindex.  Invalidates the InvIndexer.  Takes one hash-style
parameter.

=over

=item *

B<optimize> - If optimize is set to 1, the invindex will be collapsed to its
most compact form, which will yield the fastest queries.

=back

=head1 COPYRIGHT

Copyright 2005-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.164.

=cut


