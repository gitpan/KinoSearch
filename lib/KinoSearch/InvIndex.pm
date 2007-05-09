use strict;
use warnings;

package KinoSearch::InvIndex;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    schema => undef,
    folder => undef,
);

use KinoSearch::Index::IndexFileNames
    qw( WRITE_LOCK_NAME WRITE_LOCK_TIMEOUT unused_files );
use KinoSearch::Store::FSFolder;
use KinoSearch::Index::SegInfos;
use KinoSearch::Store::Lock;

sub new { confess("InvIndex's constructors are create, clobber, and open") }

sub create {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args   = ( %instance_vars, @_ );
    my $schema = $args{schema};
    my $folder = $args{folder};

    # confirm Schema
    confess("Missing required parameter 'schema'")
        unless a_isa_b( $schema, "KinoSearch::Schema" );

    # confirm or create a Folder object
    if ( !defined $folder ) {
        confess("Missing required parameter 'folder'");
    }
    elsif ( !a_isa_b( $folder, 'KinoSearch::Store::Folder' ) ) {
        # create dir if necessary
        if ( !-d $folder ) {
            mkdir $folder or confess("Couldn't mkdir '$folder': $!");
        }
        $folder = KinoSearch::Store::FSFolder->new( path => $folder );
    }

    # verify that Folder is empty
    if ( $folder->list ) {
        confess("'$args{folder}' already exists and contains files");
    }

    # initialize the invindex
    my $lock = KinoSearch::Store::Lock->new(
        folder    => $folder,
        agent_id  => "",
        lock_name => WRITE_LOCK_NAME,
        timeout   => WRITE_LOCK_TIMEOUT,
    );
    $lock->clear_stale;
    $lock->run_while_locked(
        do_body => sub {
            # write empty segments data
            my $seg_infos
                = KinoSearch::Index::SegInfos->new( schema => $schema );
            $seg_infos->write_infos($folder);
        },
    );

    return $class->_new( $schema, $folder );
}

sub clobber {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args   = ( %instance_vars, @_ );
    my $schema = $args{schema};
    my $folder = $args{folder};

    # confirm Schema
    confess("Missing required parameter 'schema'")
        unless a_isa_b( $schema, "KinoSearch::Schema" );

    # confirm or create a Folder object
    if ( !defined $folder ) {
        confess("Missing required parameter 'folder'");
    }
    elsif ( !a_isa_b( $folder, 'KinoSearch::Store::Folder' ) ) {
        # create dir if necessary
        if ( !-d $folder ) {
            mkdir $folder or confess("Couldn't mkdir '$folder': $!");
        }
        $folder = KinoSearch::Store::FSFolder->new( path => $folder );
    }

    # initialize the invindex directory
    my @all_files  = $folder->list;
    my @kino_files = unused_files( \@all_files );
    my $lock       = KinoSearch::Store::Lock->new(
        folder    => $folder,
        agent_id  => "",
        lock_name => WRITE_LOCK_NAME,
        timeout   => WRITE_LOCK_TIMEOUT,
    );
    $lock->clear_stale;
    $lock->run_while_locked(
        do_body => sub {
            # nuke existing index files
            $folder->delete_file($_) for @kino_files;

            # write empty segments data
            my $seg_infos
                = KinoSearch::Index::SegInfos->new( schema => $schema );
            $seg_infos->write_infos($folder);
        },
    );

    return $class->_new( $schema, $folder );
}

sub open {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args   = ( %instance_vars, @_ );
    my $schema = $args{schema};
    my $folder = $args{folder};

    # confirm Schema
    confess("Missing required parameter 'schema'")
        unless a_isa_b( $schema, "KinoSearch::Schema" );

    # confirm or create a Folder object
    if ( !defined $folder ) {
        confess("Missing required parameter 'folder'");
    }
    elsif ( !a_isa_b( $folder, 'KinoSearch::Store::Folder' ) ) {
        $folder = KinoSearch::Store::FSFolder->new( path => $folder );
    }

    # if an FS folder, confirm that index dir exists
    if ( $folder->isa('KinoSearch::Store::FSFolder') ) {
        my $path = $folder->get_path;
        confess("Can't open '$path'") unless -d $path;
    }

    return $class->_new( $schema, $folder );
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::InvIndex

kino_InvIndex*
_new(class, schema, folder)
    const classname_char *class;
    kino_Schema *schema;
    kino_Folder *folder;
CODE:
    CHY_UNUSED_VAR(class);
    RETVAL = kino_InvIndex_new(schema, folder);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_InvIndex *self;
ALIAS:
    get_schema = 2
    get_folder = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->schema);
             break;

    case 4:  retval = kobj_to_pobj(self->folder);
             break;
    
    END_SET_OR_GET_SWITCH
}

__POD__

=head1 NAME

KinoSearch::InvIndex - An inverted index.

=head1 SYNOPSIS

    use MySchema;
    my $invindex = MySchema->clobber('/path/to/invindex');

=head1 DESCRIPTION

"InvIndex" is short for "inverted index", the name for the data structure
which KinoSearch is based around.  Generically, an inverted index, as opposed
to any other kind of index, contains mappings from keywords to documents,
allowing you to look up a term and find out where it occurs within a
collection.

A KinoSearch::InvIndex object has two main parts: a
L<Schema|KinoSearch::Schema> and a L<Folder|KinoSearch::Store::Folder>.  The
Schema describes how the index data is structured, and the Folder provides the
I/O capabilities for actually getting at the data and doing something with it.

=head1 CONSTRUCTORS

InvIndex provides three constructors: create(), clobber(), and open().  They
all take two hash-style params.

=over

=item *

B<schema> - an instance of an object which isa KinoSearch::Schema.

=item *

B<folder> - Either an object which isa L<KinoSearch::Store::Folder>, or a
filepath.  If a filepath is supplied, an
L<FSFolder|KinoSearch::Store::FSFolder> object will be created.

=back

These constructors are usually called via factory methods from Schema:

    my $invindex = MySchema->clobber($filepath);

    # ... is the same as...

    my $invindex = KinoSearch::InvIndex->clobber(
        schema => MySchema->new,
        folder => KinoSearch::Store::FSFolder->new( path => $filepath ),
    );

However, when called directly, InvIndex's constructors allow you more
flexibility in supplying the C<folder> argument, so you can do things like
supply a L<RAMFolder|KinoSearch::Store::RAMFolder>.

=head2 create 

    my $invindex = KinoSearch::InvIndex->create(
        schema => MySchema->new,
        folder => $path_or_folder_obj,
    );

Initialize a new invindex, creating a directory on the file system if
appropriate.  Fails unless the Folder is empty.

=head2 clobber

    my $invindex = KinoSearch::InvIndex->clobber(
        schema => MySchema->new,
        folder => $path_or_folder_obj,
    );

Similar to create, but firsts attempts to delete any files within the Folder
that look like index files.  

=head2 open

    my $invindex = KinoSearch::InvIndex->open(
        schema => MySchema->new,
        folder => $path_or_folder_obj,
    );

Open an existing invindex for either reading or updating.

=head1 METHODS

=head2 get_folder get_invindex

Getters for folder and invindex.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
