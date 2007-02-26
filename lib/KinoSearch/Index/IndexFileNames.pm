use strict;
use warnings;

package KinoSearch::Index::IndexFileNames;
use KinoSearch::Util::ToolSet;

use base qw( Exporter );

use KinoSearch::Util::StringHelper qw( to_base36 from_base36 );
use KinoSearch::Util::CClass qw( to_kino );

our @EXPORT_OK = qw(
    SEGMENTS
    DELETEABLE
    SORTFILE_EXTENSION
    DEL_EXTENSION
    @INDEX_EXTENSIONS
    @COMPOUND_EXTENSIONS
    @SCRATCH_EXTENSIONS

    WRITE_LOCK_NAME
    WRITE_LOCK_TIMEOUT

    filename_from_gen
    gen_from_file_name
    unused_files

    IXINFOS_FORMAT
    SEG_INFOS_FORMAT
    COMPOUND_FILE_FORMAT
    DOC_STORAGE_FORMAT
    TERM_LIST_FORMAT
    POSTING_LIST_FORMAT
    DELDOCS_FORMAT
);

# base name of the index segments file
use constant SEGMENTS => 'segments';

# extension of the temporary file used by the SortExternal sort pool
use constant SORTFILE_EXTENSION => '.srt';

# extension used by per-segment deletions file
use constant DEL_EXTENSION => '.del';

# Most, but not all of Lucene file extenstions. Missing are the ".p$num"
# ".tl$num", and ".tlx$num" extensions.
our @INDEX_EXTENSIONS = qw( cf ds dsx tv tvx del yaml );

# extensions for files which are subsumed into the cf compound file
our @COMPOUND_EXTENSIONS = qw( ds dsx tv tvx );

our @SCRATCH_EXTENSIONS = qw( srt );

# names and constants for lockfiles
use constant WRITE_LOCK_NAME    => 'write.lock';
use constant WRITE_LOCK_TIMEOUT => 1000;

sub gen_from_file_name {
    my $filename = shift;
    return 0 unless defined $filename;
    return 0 unless $_[0] =~ /^.+_(\d+)/;
    return $1;
}

my %extensions_hash;
for ( @INDEX_EXTENSIONS, @COMPOUND_EXTENSIONS, @SCRATCH_EXTENSIONS ) {
    $extensions_hash{$_} = 1;
}

# Determine which KinoSearch files in the InvIndex are not currently in use.
# Leave non-KS files alone.
sub unused_files {
    my ( $files, $seg_infos ) = @_;
    my @unused;

    # create a hash of seg names for quick look up.
    my %active_segs;
    if ( defined $seg_infos ) {
        for ( $seg_infos->infos ) {
            $active_segs{ $_->get_seg_name } = 1;
        }
    }

    my %generational_files;
    for (@$files) {
        if (m{
                ^(_[a-z0-9]+)     # seg name
                 (_[a-z0-9]+)?    # generation (optional)
                 \.(.*)$          # extension
            }x
            )
        {
            my ( $seg_name, $gen, $ext ) = ( $1, $2, $3 );
            next
                unless ( exists $extensions_hash{$ext}
                or $ext =~ /^(p|tl|tlx)\d+$/ );
            if ( defined $gen and bytes::length $gen ) {
                if ( !defined $seg_infos ) {
                    # if no seg_infos, discard all generational files too
                    push @unused, $_;

                }
                else {
                    # keep generational files around for testing later
                    $generational_files{$_} = from_base36($gen);
                }
            }

            # if it doesn't belong to a current segment, chuck it
            if ( !exists $active_segs{$seg_name} ) {
                push @unused, $_;
                next;
            }

        }
        elsif (/^(segments|invindex)_(\w+).yaml$/) {
            if ( defined $seg_infos ) {
                $generational_files{$_} = from_base36($2);
            }
            else {
                push @unused, $_;
            }
        }
    }

    # keep only the most recent generational files
    my @sorted_gen_files
        = sort { $generational_files{$a} <=> $generational_files{$b} }
        keys %generational_files;
    my $last_base = "";
    for ( reverse @sorted_gen_files ) {
        my ($base) = /^(\w+)_\w+\./;
        if ( $base eq $last_base ) {
            push @unused, $_;
        }
        $last_base = $base;
    }

    return @unused;
}

sub latest_gen {
    my ( $filenames, $base, $ext ) = @_;
    return _latest_gen( to_kino($filenames), $base, $ext );
}

1;

__END__

__XS__

MODULE = KinoSearch  PACKAGE = KinoSearch::Index::IndexFileNames

SV*
_latest_gen(file_list, base, ext)
    kino_VArray *file_list;
    kino_ByteBuf base;
    kino_ByteBuf ext;
CODE:
{
    kino_ByteBuf *file = kino_IxFileNames_latest_gen(file_list, &base, &ext);
    RETVAL = file == NULL
        ? newSV(0)
        : bb_to_sv(file);
    REFCOUNT_DEC(file);
}
OUTPUT: RETVAL

SV*
filename_from_gen(base, gen, ext)
    kino_ByteBuf base;
    kino_i32_t   gen;
    kino_ByteBuf ext;
CODE:
{
    kino_ByteBuf *file = kino_IxFileNames_filename_from_gen(&base, gen, &ext);
    RETVAL = file == NULL
        ? newSV(0)
        : bb_to_sv(file);
    REFCOUNT_DEC(file);
}
OUTPUT: RETVAL

IV
IXINFOS_FORMAT()
CODE:
    RETVAL = KINO_IXINFOS_FORMAT;
OUTPUT: RETVAL

IV
SEG_INFOS_FORMAT()
CODE:
    RETVAL = KINO_SEG_INFOS_FORMAT;
OUTPUT: RETVAL

IV
COMPOUND_FILE_FORMAT()
CODE:
    RETVAL = KINO_COMPOUND_FILE_FORMAT;
OUTPUT: RETVAL

IV
DOC_STORAGE_FORMAT()
CODE:
    RETVAL = KINO_DOC_STORAGE_FORMAT;
OUTPUT: RETVAL

IV
TERM_LIST_FORMAT()
CODE:
    RETVAL = KINO_TERM_LIST_FORMAT;
OUTPUT: RETVAL

IV
POSTING_LIST_FORMAT()
CODE:
    RETVAL = KINO_POSTING_LIST_FORMAT;
OUTPUT: RETVAL

IV
DELDOCS_FORMAT()
CODE:
    RETVAL = KINO_DELDOCS_FORMAT;
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::IndexFileNames - Filenames and suffixes used in an InvIndex.

=head1 DESCRIPTION

This module abstracts the names of the files that make up an InvIndex,
similarly to the way InStream and OutStream abstract filehandle operations.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
