use strict;
use warnings;

package KinoSearch::Index::IndexFileNames;
use KinoSearch::Util::ToolSet;

use base qw( Exporter );

use KinoSearch::Util::StringHelper qw( to_base36 from_base36 );
use KinoSearch::Util::Native qw( to_kino );

our @EXPORT_OK = qw(
    SEGMENTS
    DELETEABLE
    SORTFILE_EXTENSION
    DEL_EXTENSION
    @INDEX_EXTENSIONS
    @COMPOUND_EXTENSIONS
    @SCRATCH_EXTENSIONS

    READ_LOCK_TIMEOUT
    WRITE_LOCK_NAME
    WRITE_LOCK_TIMEOUT
    COMMIT_LOCK_NAME
    COMMIT_LOCK_TIMEOUT

    filename_from_gen
    gen_from_filename
    unused_files

    IXINFOS_FORMAT
    SEG_INFOS_FORMAT
    COMPOUND_FILE_FORMAT
    DOC_STORAGE_FORMAT
    LEXICON_FORMAT
    POSTING_LIST_FORMAT
    DELDOCS_FORMAT
);

# extension of the temporary file used by the SortExternal sort pool
use constant SORTFILE_EXTENSION => '.srt';

# extension used by per-segment deletions file
use constant DEL_EXTENSION => '.del';

# Most, but not all file extenstions. Missing are the ".p$num" ".lex$num",
# and ".lexx$num" extensions.
our @INDEX_EXTENSIONS = qw( cf ds dsx tv tvx del skip yaml );

# extensions for files which are subsumed into the cf compound file
our @COMPOUND_EXTENSIONS = qw( ds dsx tv tvx skip );

our @SCRATCH_EXTENSIONS = qw( srt ptemp lextemp tvxtemp dsxtemp );

sub gen_from_filename {
    my $filename = shift;
    return 0 unless defined $filename;
    return 0 unless $filename =~ /^.+_(\w+)/;
    return from_base36($1);
}

my %extensions_hash;
for ( @INDEX_EXTENSIONS, @COMPOUND_EXTENSIONS, @SCRATCH_EXTENSIONS ) {
    $extensions_hash{$_} = 1;
}

# Determine which KinoSearch files in the InvIndex are not currently in use.
# Leave non-KS files alone.
sub unused_files {
    my ( $files, @seg_infoses ) = @_;
    my @unused;
    my %keep;
    my @generational_files;

    # create hash of active segs, plus record which master files are in use
    my %active_segs;
    for my $seg_infos (@seg_infoses) {
        for ( $seg_infos->infos ) {
            $active_segs{ $_->get_seg_name } = 1;
        }
        my $segments_file_name
            = filename_from_gen( "segments", $seg_infos->get_generation,
            '.yaml' );
        $keep{$segments_file_name} = 1;
    }

    for (@$files) {
        next if /\.lock$/;
        next if $keep{$_};

        if (m{
                ^(_[a-z0-9]+)         # seg name
                 (_[a-z0-9]+)?    # generation (optional)
                 \.(.*)$              # extension
            }x
            )
        {
            my ( $seg_name, $gen, $ext ) = ( $1, $2, $3 );

            # if no seg infos, discard all index files
            if ( !@seg_infoses ) {
                push @unused, $_;
                next;
            }

            # ensure that file has a recognized extension
            next
                unless ( exists $extensions_hash{$ext}
                or $ext =~ /^(?:p|lex|lexx)\d+$/ );

            # if it doesn't belong to a current segment, chuck it
            if ( !exists $active_segs{$seg_name} ) {
                push @unused, $_;
                next;
            }

            # if it's a .del file with a generation, defer decision
            if ( defined $gen and bytes::length $gen ) {
                push @generational_files, $_;
                next;
            }
        }
        elsif (/^segments_\w+\.yaml$/) {
            push @unused, $_;
        }
    }

    # keep only the most recent generational files
    my @sorted_gen_files = map { $_->[0] }
        sort { $b->[1] <=> $a->[1] }
        map { [ $_, _seg_then_gen($_) ] } @generational_files;
    my $last_base = "";
    for (@sorted_gen_files) {
        my ($base) = /^(\w+)_\w+\./;
        if ( $base eq $last_base ) {
            push @unused, $_;
        }
        $last_base = $base;
    }

    return @unused;
}

sub _seg_then_gen {
    my $filename = shift;
    $filename =~ /^_([a-z0-9]+)_([a-z0-9]+)/
        or confess("no match: $filename");
    my ( $seg_name, $gen ) = ( $1, $2 );
    return sprintf( "%.12d%.12d", from_base36($seg_name), from_base36($gen) );
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
    chy_i32_t    gen;
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
LEXICON_FORMAT()
CODE:
    RETVAL = KINO_LEXICON_FORMAT;
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

IV
READ_LOCK_TIMEOUT()
CODE:
    RETVAL = KINO_READ_LOCK_TIMEOUT;
OUTPUT: RETVAL

const char*
WRITE_LOCK_NAME()
CODE:
    RETVAL = KINO_WRITE_LOCK_NAME;
OUTPUT: RETVAL

IV
WRITE_LOCK_TIMEOUT()
CODE:
    RETVAL = KINO_WRITE_LOCK_TIMEOUT;
OUTPUT: RETVAL

const char*
COMMIT_LOCK_NAME()
CODE:
    RETVAL = KINO_COMMIT_LOCK_NAME;
OUTPUT: RETVAL

IV
COMMIT_LOCK_TIMEOUT()
CODE:
    RETVAL = KINO_COMMIT_LOCK_TIMEOUT;
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

See L<KinoSearch> version 0.20.

=end devdocs
=cut
