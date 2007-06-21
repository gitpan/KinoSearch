use strict;
use warnings;

package KinoSearch::Store::FSFolder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Folder );
use File::Spec::Functions qw( rel2abs );

our %instance_vars = (
    # inherited
    path => undef,
);

sub new {
    my $class = shift;
    my %args  = @_;
    confess("Missing required parameter 'path'") unless defined $args{path};
    return $class->_new( rel2abs( $args{path} ) );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::FSFolder

kino_FSFolder*
_new(classname, path)
    const classname_char *classname;
    kino_ByteBuf path;
CODE:
    RETVAL = kino_FSFolder_new(&path);
    CHY_UNUSED_VAR(classname);
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Store::FSFolder - File System implementation of Folder.

=head1 SYNOPSIS

    my $folder = KinoSearch::Store::FSFolder->new(
        path   => '/path/to/folder',
    );

=head1 DESCRIPTION

Implementation of KinoSearch::Store::Folder using a single file system 
directory and multiple files.

=head1 METHODS

=head2 new

    my $folder = KinoSearch::Store::FSFolder->new(
        path   => '/path/to/folder',
    );

Constructor. Takes one hash-style parameter.

If the directory does not exist already, it will B<NOT> be created, in order
to prevent misconfigured read applications from spawning bogus files -- so it
may be necessary to create the directory yourself.

=over 

=item

B<path> - the location of the folder.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
