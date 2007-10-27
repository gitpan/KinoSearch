use strict;
use warnings;

package KinoSearch::Store::Folder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # params
    path => undef,
);

use KinoSearch::Store::InStream;
use KinoSearch::Store::OutStream;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::Folder

kino_OutStream*
open_outstream(self, filename)
    kino_Folder *self;
    kino_ByteBuf filename;
CODE:
    RETVAL = Kino_Folder_Open_OutStream(self, &filename);
OUTPUT: RETVAL

SV*
safe_open_outstream(self, filename)
    kino_Folder *self;
    kino_ByteBuf filename;
CODE:
{
    kino_OutStream *outstream 
        = Kino_Folder_Safe_Open_OutStream(self, &filename);
    RETVAL = outstream == NULL
        ? newSV(0)
        : kobj_to_pobj(outstream);
    REFCOUNT_DEC(outstream);
}
OUTPUT: RETVAL

kino_InStream*
open_instream(self, filename)
    kino_Folder *self;
    kino_ByteBuf filename;
CODE:
    RETVAL = Kino_Folder_Open_InStream(self, &filename);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_Folder *self;
ALIAS:
    get_path   = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = bb_to_sv(self->path);
             break;

    END_SET_OR_GET_SWITCH
}

void
list(self)
    kino_Folder *self;
PPCODE:
{
    kino_VArray *file_list = Kino_Folder_List(self);
    chy_u32_t size = file_list->size;
    chy_u32_t i;

    EXTEND(SP, size);
    
    /* output in list context */
    for (i = 0; i < size; i++) {
        kino_ByteBuf *const filename 
            = (kino_ByteBuf*)Kino_VA_Fetch(file_list, i);
        SV *const element_sv = bb_to_sv(filename);
        PUSHs( sv_2mortal(element_sv) );
    }

    REFCOUNT_DEC(file_list);

    XSRETURN(size);
}

IV
file_exists(self, filename)
    kino_Folder *self;
    kino_ByteBuf filename;
CODE:
    RETVAL = Kino_Folder_File_Exists(self, &filename);
OUTPUT: RETVAL
    
    
void
rename_file(self, from, to)
    kino_Folder *self;
    kino_ByteBuf from;
    kino_ByteBuf to;
PPCODE:
    Kino_Folder_Rename_File(self, &from, &to);

void
delete_file(self, filename);
   kino_Folder *self;
   kino_ByteBuf filename;
PPCODE:
    Kino_Folder_Delete_File(self, &filename);

SV*
slurp_file(self, filename);
    kino_Folder *self;
    kino_ByteBuf filename;
CODE:
{
    kino_ByteBuf *contents_bb = Kino_Folder_Slurp_File(self, &filename);
    RETVAL = bb_to_sv(contents_bb);
    REFCOUNT_DEC(contents_bb);
}
OUTPUT: RETVAL

SV*
latest_gen(self, base, ext);
    kino_Folder *self;
    kino_ByteBuf base;
    kino_ByteBuf ext;
CODE:
{
    kino_ByteBuf *name = Kino_Folder_Latest_Gen(self, &base, &ext);
    RETVAL = name == NULL 
        ? newSV(0)
        : bb_to_sv(name);
    REFCOUNT_DEC(name);
}
OUTPUT: RETVAL

void
close(self)
    kino_Folder *self;
PPCODE:
    Kino_Folder_Close_F(self);

__POD__


=head1 NAME

KinoSearch::Store::Folder - Abstract class representing a directory.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

The archetypal implementation of Folder,
L<FSFolder|KinoSearch::Store::FSFolder>, is a single directory on the file
system holding a collection of files.  However, to allow alternative
implementations such as RAMFolder, i/o and file manipulation are abstracted
out rather than executed directly by KinoSearch's classes.

A "file" within an folder might be a real file on disk-- or it might be a ram
file.  Similarly, C<< $folder->delete_file($filename) >> might delete a file
from the file system, or a key-value pair from a hash, or something else.

=head1 SEE ALSO

L<KinoSearch::Docs::FileFormat>

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
