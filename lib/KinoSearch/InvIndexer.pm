package KinoSearch::InvIndexer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use Clone qw( clone );
use File::Spec::Functions qw( catfile tmpdir );
use File::Temp qw();
use Math::BaseCalc;
use Sort::External;

use KinoSearch::Document::Doc;
use KinoSearch::Document::Field;
use KinoSearch::Analysis::Analyzer;
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Index::FieldInfos;
use KinoSearch::Index::FieldsReader;
use KinoSearch::Index::SegWriter;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::IndexFileNames
    qw( WRITE_LOCK_NAME    COMMIT_LOCK_NAME
    WRITE_LOCK_TIMEOUT COMMIT_LOCK_TIMEOUT );
use KinoSearch::Search::Similarity;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args / members
    create   => undef,
    invindex => undef,
    analyzer => KinoSearch::Analysis::Analyzer->new,

    # members
    analyzers    => {},
    sinfos       => KinoSearch::Index::SegInfos->new,
    finfos       => KinoSearch::Index::FieldInfos->new,
    doc_template => KinoSearch::Document::Doc->new,
    similarity   => undef,
    seg_writer   => undef,

    write_lock  => undef,
    initialized => 0,
);

sub init_instance {
    my $self = shift;

    # get a similarity object
    $self->{similarity} = KinoSearch::Search::Similarity->new;

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
    my $write_lock = $self->{write_lock} = $invindex->make_lock(
        lock_name => WRITE_LOCK_NAME,
        timeout   => WRITE_LOCK_TIMEOUT,
    );
    $write_lock->obtain
        or croak( "invindex locked: " . $write_lock->get_lock_name );

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

    # more initialization is coming after fields are spec'd...
}

sub _delayed_init {
    my $self = shift;
    $self->{initialized} = 1;
    my ( $invindex, $finfos ) = @{$self}{ 'invindex', 'finfos' };

    # create a Doc object which will serve as a cloning template
    my $doc = $self->{doc_template};
    for my $field ( $doc->get_fields ) {
        $field->set_field_num( $finfos->get_field_num( $field->get_name ) );
    }

    # name a new segment and create a SegWriter
    my $out_seg_name = $self->_new_seg_name;
    $self->{seg_writer} = KinoSearch::Index::SegWriter->new(
        invindex   => $invindex,
        seg_name   => $out_seg_name,
        finfos     => $finfos->clone,
        similarity => $self->{similarity},
    );
}

sub spec_field {
    my $self = shift;

    # don't allow new fields to be spec'd once the seg is in motion
    croak("Too late to spec field (new_doc has been called)")
        if $self->{initialized};

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
    $self->_delayed_init unless $self->{initialized};
    return clone( $self->{doc_template} );
}

sub add_doc {
    my ( $self, $doc ) = @_;

    # perform analysis
    for my $field ( $doc->get_fields ) {
        next unless $field->get_value_len;
        my $fieldname = $field->get_name;
        if ( $field->get_analyzed ) {
            my $analyzer
                = ( $field->get_analyzer || $self->{analyzers}{$fieldname} );
            $analyzer->analyze($field);
        }
    }

    # add doc to output segment
    $self->{seg_writer}->add_doc($doc);
}

sub finish {
    my $self     = shift;
    my $invindex = $self->{invindex};

    # finish the segment
    $self->{seg_writer}->finish;

    # now that the seg is complete, write its info to the 'segments' file
    $self->{sinfos}->add_info(
        KinoSearch::Index::SegInfo->new(
            seg_name  => $self->{seg_writer}->get_seg_name,
            doc_count => $self->{seg_writer}->get_doc_count,
            invindex  => $self->{invindex},
        )
    );
    $invindex->run_while_locked(
        lock_name => COMMIT_LOCK_NAME,
        timeout   => COMMIT_LOCK_TIMEOUT,
        do_body   => sub {
            $self->{sinfos}->write_infos($invindex);
        },
    );
}

# Release the write lock - if it's there.
sub _release_locks {
    my $self = shift;
    if ( defined $self->{write_lock} ) {
        $self->{write_lock}->release if $self->{write_lock}->is_locked;
        undef $self->{write_lock};
    }
}

my $base_calc_36 = Math::BaseCalc->new( digits => [ 0 .. 9, 'a' .. 'z' ] );

# Generate Lucene-compatible segment names.
sub _new_seg_name {
    my $self = shift;

    my $counter = $self->{sinfos}->get_counter;
    $self->{sinfos}->set_counter( ++$counter );

    return '_' . $base_calc_36->to_base($counter);
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

    $invindexer->spec_field( name => 'title' );
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
        analyzer   => undef,      # default: analyzer spec'd in new()
        indexed    => 1,          # default: 1
        analyzed   => 0,          # default: 1
        stored     => 0,          # default: 1
        compressed => 0,          # default: 0
    );

Define a field.  This is analogous to defining a field in a database.

=over

=item *

B<name> - the field's name.

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

=back

=head2 new_doc

    my $doc = $invindexer->new_doc;

Spawn an empty L<KinoSearch::Document::Doc|KinoSearch::Document::Doc> object,
primed to accept values for the fields spec'd by spec_field.

=head2 add_doc

    $invindexer->add_doc($doc);

Add a document to the invindex.

=head2 finish 

    $invindexer->finish;

Finish the invindex.  Invalidates the InvIndexer.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=cut


