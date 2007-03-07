use strict;
use warnings;

package KinoSearch::Store::Folder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars( path => undef, );
}

our %make_lock_vars = (
    lock_name => undef,
    lock_id   => '',
    timeout   => undef,
);

=begin comment

    $folder->run_while_locked(
        lock_name => $name,
        timeout   => $timeout,  # milliseconds
        do_body   => \&do_some_stuff,
    );

Create a Lock object and obtain a lock, run the subroutine specified by
the do_body parameter, then release the lock and discard the Lock object.
The hash-style argument labels include all the arguments to make_lock, plus
do_body.

=end comment
=cut

our %run_while_locked_vars = (
    do_body   => undef,
    lock_name => undef,
    lock_id   => '',
    timeout   => undef,
);

sub run_while_locked {
    my ( $self, %args ) = @_;
    my $do_body = delete $args{do_body};
    my $lock    = $self->make_lock(%args);
    my $locked;
    eval {
        $locked = $lock->obtain;
        $do_body->();
    };
    $lock->release if $lock->is_locked;
    confess $@     if $@;
}

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
    kino_u32_t size = file_list->size;
    kino_u32_t i;

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

kino_Lock*
make_lock(self, ...)
    kino_Folder *self;
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Store::Folder::make_lock_vars");
    kino_i32_t timeout     = extract_iv(args_hash, SNL("timeout"));
    SV *lock_name_sv       = extract_sv(args_hash, SNL("lock_name"));
    SV *lock_id_sv         = extract_sv(args_hash, SNL("lock_id"));
    kino_ByteBuf lock_name = KINO_BYTEBUF_BLANK;
    kino_ByteBuf lock_id   = KINO_BYTEBUF_BLANK;
    SV_TO_TEMP_BB(lock_name_sv, lock_name);
    SV_TO_TEMP_BB(lock_id_sv, lock_id);
    
    RETVAL = Kino_Folder_Make_Lock(self, &lock_name, &lock_id, timeout);
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

