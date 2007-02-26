use strict;
use warnings;

package KinoSearch::Store::FSFolder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::Folder );

BEGIN {
    __PACKAGE__->init_instance_vars();
}
our %instance_vars;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::FSFolder

kino_FSFolder*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::FSFolder::instance_vars");
    kino_ByteBuf path;
    SV *path_sv =  extract_sv(args_hash, SNL("path"));
    if (!SvOK(path_sv))
        CONFESS("Missing required argument 'path'");
    SV_TO_TEMP_BB(path_sv, path);
    
    RETVAL = kino_FSFolder_new(&path);
}
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

=head1 CONSTRUCTOR

=head2 new

C<new> takes one hash-style parameter:

=over 

=item

B<path> - the location of the folder.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut
