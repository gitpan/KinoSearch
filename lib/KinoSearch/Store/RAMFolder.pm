use strict;
use warnings;

package KinoSearch::Store::RAMFolder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Folder );

our %instance_vars = (
    # inherited
    path => undef,
);

use KinoSearch::Store::FSFolder;
use KinoSearch::Store::RAMFileDes;
use KinoSearch::Store::InStream;
use KinoSearch::Store::OutStream;

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    my $path = defined $args{path} ? $args{path} : '';
    my $self = $class->_new($path);

    # read in an FSFolder if specified
    $self->_read_folder($path) if defined $args{path};

    return $self;
}

sub _read_folder {
    my $self = shift;

    # open an FSFolder for reading
    my $source_folder
        = KinoSearch::Store::FSFolder->new( path => $self->get_path );

    # copy every file in the FSFolder into RAM.
    for my $filename ( $source_folder->list ) {
        my $source_stream = $source_folder->open_instream($filename);
        my $outstream     = $self->open_outstream($filename);
        $outstream->absorb($source_stream);
        $source_stream->sclose;
        $outstream->sclose;
    }

    $source_folder->close;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::RAMFolder

kino_RAMFolder*
_new(class, path)
    const classname_char *class;
    kino_ByteBuf path;
CODE:
    CHY_UNUSED_VAR(class);
    RETVAL = kino_RAMFolder_new(&path);
OUTPUT: RETVAL

kino_RAMFileDes*
ram_file(self, filename)
    kino_RAMFolder *self;
    kino_ByteBuf filename;
CODE:
    RETVAL = (kino_RAMFileDes*)Kino_Hash_Fetch_BB(self->ram_files, &filename);
    if (RETVAL == NULL)
        CONFESS( "File '%s' not loaded into RAM", filename.ptr);
    REFCOUNT_INC(RETVAL);
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Store::RAMFolder - In-memory Folder.

=head1 SYNOPSIS
    

    my $folder = KinoSearch::Store::RAMFolder->new;

    # or sometimes...
    my $folder = KinoSearch::Store::RAMFolder->new(
        path   => '/path/to/folder',
    );



=head1 DESCRIPTION

RAMFolder is an entirely in-memory implementation of
KinoSearch::Store::Folder.  It serves two main purposes.

First, it's possible to load an existing FSFolder into memory, which can
improve search-speed -- if you have that kind of RAM to spare.  Needless to
say, any FSFolder you try to load this way should be appropriately modest in
size.

Second, RAMFolder is handy for testing and development.

=head1 METHODS

=head2 new

    my $folder = KinoSearch::Store::RAMFolder->new(
        path   => '/path/to/folder',   # optional
    );

Constructor. Takes one optional parameter, C<path>. If C<path> is supplied,
KinoSearch will try to read an FSFolder at that location into memory;
otherwise the Folder starts out empty.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
