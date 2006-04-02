package KinoSearch::Util::SortExternal;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args
    invindex      => undef,
    seg_name      => undef,
    mem_threshold => 2**24,
);

sub new {
    my $class = shift;
    verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    $class = ref($class) || $class;

    my $outstream = $args{invindex}->open_outstream("$args{seg_name}.srt");

    return _new( $class, $outstream,
        @args{qw( invindex seg_name mem_threshold )} );

}

# Prepare to start fetching sorted results.
sub sort_all {
    my $self = shift;

    # deal with any items in the cache right now
    if ( $self->_get_num_runs == 0 ) {
        # if we've never exceeded mem_threshold, sort in-memory
        $self->_sort_cache;
    }
    else {
        # create a run from whatever's in the cache right now
        $self->_sort_run;
    }

    # done adding elements, so close file and reopen as an instream
    $self->_get_outstream->close;
    my $filename = $self->_get_seg_name . ".srt";
    my $instream = $self->_get_invindex()->open_instream($filename);
    $self->_set_instream($instream);

    # allow fetching now that we're set up
    $self->_enable_fetch;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::SortExternal

void
_new(class, outstream_sv, invindex_sv, seg_name_sv, mem_threshold)
    char         *class;
    SV           *outstream_sv;
    SV           *invindex_sv;
    SV           *seg_name_sv;
    I32           mem_threshold;
PREINIT:
    SortExternal *sortex;
PPCODE:
    sortex = Kino_SortEx_new(outstream_sv, invindex_sv, seg_name_sv,
        mem_threshold);
    ST(0)  = sv_newmortal();
    sv_setref_pv( ST(0), class, (void*)sortex );
    XSRETURN(1);

=for comment

Add one or more items to the sort pool.

=cut

void
feed(sortex, ...)
    SortExternal *sortex;
PREINIT:
    I32 i;
PPCODE:
    for (i = 1; i < items; i++) {   
        sortex->feed(sortex, ST(i));
    }

=for comment

Fetch the next sorted item from the sort pool.  sort_all must be called first.

=cut

SV*
fetch(sortex)
    SortExternal *sortex;
CODE:
    RETVAL = sortex->fetch(sortex);
OUTPUT: RETVAL

=for comment

Sort all items currently in memory.

=cut

void
_sort_cache(sortex)
    SortExternal *sortex;
PPCODE:
    Kino_SortEx_sort_cache(sortex);

=for comment

Sort everything in memory and write the sorted elements to disk, creating a
SortExRun C object.

=cut

void
_sort_run(sortex);
    SortExternal *sortex;
PPCODE:
    Kino_SortEx_sort_run(sortex);

=for comment

Turn on fetching.

=cut

void
_enable_fetch(sortex)
    SortExternal *sortex;
PPCODE:
    Kino_SortEx_enable_fetch(sortex);
    
SV*
_set_or_get(sortex, ...)
    SortExternal *sortex;
ALIAS:
    _set_outstream = 1
    _get_outstream = 2
    _set_instream  = 3
    _get_instream  = 4
    _set_num_runs  = 5
    _get_num_runs  = 6
    _set_invindex  = 7
    _get_invindex  = 8
    _set_seg_name  = 9
    _get_seg_name  = 10
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        croak("usage: $term_info->set_xxxxxx($val)");
    
    switch (ix) {

    case 1:  SvREFCNT_dec(sortex->outstream_sv);
             sortex->outstream_sv = newSVsv( ST(1) );
             Kino_extract_struct(sortex->outstream_sv, sortex->outstream, 
                OutStream*, "KinoSearch::Store::OutStream");
             /* fall through */
    case 2:  RETVAL = newSVsv(sortex->outstream_sv);
             break;
             
    case 3:  SvREFCNT_dec(sortex->instream_sv);
             sortex->instream_sv = newSVsv( ST(1) );
             Kino_extract_struct(sortex->instream_sv, sortex->instream, 
                InStream*, "KinoSearch::Store::InStream");
             /* fall through */
    case 4:  RETVAL = newSVsv(sortex->instream_sv);
             break;

    case 5:  Kino_confess("can't set num_runs");
             /* fall through */
    case 6:  RETVAL = newSViv(sortex->num_runs);
             break;

    case 7:  Kino_confess("can't set_invindex");
             /* fall through */
    case 8:  RETVAL = newSVsv(sortex->invindex_sv);
             break;
             
    case 9:  Kino_confess("can't set_seg_name");
             /* fall through */
    case 10: RETVAL = newSVsv(sortex->seg_name_sv);
             break;
    }
}
OUTPUT: RETVAL

void
DESTROY(sortex)
    SortExternal *sortex;
PPCODE:
    Kino_SortEx_destroy(sortex);

__H__

#ifndef H_KINOSEARCH_UTIL_SORT_EXTERNAL
#define H_KINOSEARCH_UTIL_SORT_EXTERNAL 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "KinoSearchStoreInStream.h"
#include "KinoSearchStoreOutStream.h"
#include "KinoSearchUtilCClass.h"
#include "KinoSearchUtilStringHelper.h"

typedef struct sortexrun {
    double    start;
    double    pos;
    double    end;
    AV       *cache;
} SortExRun;

typedef struct sortexternal {
    AV         *cache;
    I32         mem_threshold;
    I32         cache_bytes;
    I32         run_cache_limit;
    SortExRun **runs;
    I32         num_runs;
    I32         num_big_runs;
    SV         *outstream_sv;
    OutStream  *outstream;
    SV         *instream_sv;
    InStream   *instream;
    SV         *invindex_sv;
    SV         *seg_name_sv;
    void      (*feed) (struct sortexternal*, SV*);
    SV*       (*fetch)(struct sortexternal*);
} SortExternal;

SortExternal* Kino_SortEx_new(SV*, SV*, SV*, I32);
void Kino_SortEx_feed(SortExternal*, SV*);
SV*  Kino_SortEx_fetch(SortExternal*);
SV*  Kino_SortEx_fetch_death(SortExternal*);
void Kino_SortEx_sort_cache(SortExternal*);
void Kino_SortEx_destroy(SortExternal *sortex);

#endif /* include guard */

__C__

#include "KinoSearchUtilSortExternal.h"

static SortExRun* Kino_SortEx_new_run(double, double);
static bool       Kino_SortEx_refill_run(SortExternal*, SortExRun*);
static void       Kino_SortEx_refill_cache(SortExternal*);
static SV*        Kino_SortEx_find_endpost(SortExternal *sortex);
static void       Kino_SortEx_gatekeeper(SortExternal*, SortExRun*, SV*);
static I32        Kino_SortEx_find_max_in_range(AV*, SV*);
static void       Kino_SortEx_destroy_run(SortExRun *run);

/* a rough estimate */
#define KINO_PER_ITEM_OVERHEAD (sizeof(SV) + sizeof(XPV) + sizeof(SV*))

SortExternal*
Kino_SortEx_new(SV *outstream_sv, SV *invindex_sv, SV *seg_name_sv, 
                I32 mem_threshold) {
    SortExternal *sortex;

    /* allocate */
    Kino_New(0, sortex, 1, SortExternal);
    sortex->cache = newAV();
    Kino_New(0, sortex->runs, 1, SortExRun*);

    /* init */
    sortex->cache_bytes     = 0;
    sortex->num_runs        = 0;
    sortex->num_big_runs    = 0;
    sortex->instream_sv     = &PL_sv_undef;
    sortex->feed            = Kino_SortEx_feed;
    sortex->fetch           = Kino_SortEx_fetch_death;

    /* assign */
    sortex->outstream_sv  = newSVsv(outstream_sv);
    Kino_extract_struct(outstream_sv, sortex->outstream,
        OutStream*, "KinoSearch::Store::OutStream");
    sortex->invindex_sv   = newSVsv(invindex_sv);
    sortex->seg_name_sv   = newSVsv(seg_name_sv);
    sortex->mem_threshold = mem_threshold;
    
    /* derive */
    sortex->run_cache_limit = mem_threshold / 2;

    return sortex;
}


static SortExRun*
Kino_SortEx_new_run(double start, double end) {
    SortExRun *run;
    
    /* allocate */
    Kino_New(0, run, 1, SortExRun);
    run->cache = newAV();

    /* assign */
    run->start = start;
    run->pos   = start;
    run->end   = end;

    return run;
}

void
Kino_SortEx_feed(SortExternal* sortex, SV* input_sv) {
    SV * const item_sv = newSV(0);
    if (input_sv != NULL) {
        SvSetSV(item_sv, input_sv);
        av_push(sortex->cache, item_sv);
        
        /* track memory consumed */
        sortex->cache_bytes += KINO_PER_ITEM_OVERHEAD;
        if (SvPOK(item_sv))
            sortex->cache_bytes += SvLEN(item_sv);
    }

    /* check if it's time to flush the cache */
    if (sortex->cache_bytes >= sortex->mem_threshold)
        Kino_SortEx_sort_run(sortex);
}

void
Kino_SortEx_sort_cache(SortExternal *sortex) {
    sortsv(AvARRAY(sortex->cache), av_len(sortex->cache)+1, Perl_sv_cmp);
}

Kino_SortEx_sort_run(SortExternal *sortex) {
    I32         i, max;
    OutStream  *outstream;
    AV         *cache_av;
    SV        **sv_ptr;
    char       *string;
    STRLEN      len;
    double      start, end;

    /* bail if there's nothing in the cache */
    if (sortex->cache_bytes == 0)
        return;

    /* allocate space for a new run */
    sortex->num_runs++;
    Kino_Renew(sortex->runs, sortex->num_runs, SortExRun*);

    /* make local copies */
    outstream = sortex->outstream;
    cache_av  = sortex->cache;

    /* mark start of run */
    start = outstream->tell(outstream);
    
    /* write sorted items to file */
    Kino_SortEx_sort_cache(sortex);
    max = av_len(cache_av); 
    for (i = 0; i <= max; i++) {
        /* retrieve one scalar from the input_array */
        sv_ptr  = av_fetch(cache_av, i, 0);
        if (sv_ptr == NULL) 
            Kino_confess("sort_run: NULL sv_ptr");
        string     = SvPV(*sv_ptr, len);

        outstream->write_vint(outstream, len);
        outstream->write_bytes(outstream, string, len);
    }

    /* clear the cache */
    av_clear(cache_av);
    sortex->cache_bytes = 0;

    /* mark end of run and build a new SortExRun object */
    end = outstream->tell(outstream);
    sortex->runs[ sortex->num_runs - 1 ] = Kino_SortEx_new_run(start, end);

    /* recalculate the size allowed for each run's cache */
    sortex->run_cache_limit = (sortex->mem_threshold / 2) / sortex->num_runs;
}

Kino_SortEx_enable_fetch(SortExternal *sortex) {
    sortex->fetch = Kino_SortEx_fetch;
}

SV*
Kino_SortEx_fetch_death(SortExternal *sortex) {
    Kino_confess("can't call fetch before sort_all");
}

SV*
Kino_SortEx_fetch(SortExternal *sortex) {
    SV* retval_sv;
    if (av_len(sortex->cache) == -1)
        Kino_SortEx_refill_cache(sortex);
    
    retval_sv = av_shift(sortex->cache);
    return retval_sv;
}

/* Recover scalars from disk */
static bool
Kino_SortEx_refill_run(SortExternal* sortex, SortExRun *run) {
    InStream *instream;
    double    end;
    SV       *scratch_sv;
    char     *read_buf;
    STRLEN    len;
    I32       run_cache_bytes = 0;
    int       num_items       = 0; /* number of items recovered */
    AV       *run_cache_av;
    const I32 run_cache_limit = sortex->run_cache_limit;

    /* make local copies */
    instream        = sortex->instream;
    end             = run->end;
    run_cache_av    = run->cache;

    if (av_len(run_cache_av) != -1)
        return TRUE;

    instream->seek(instream, run->pos);

    while (1) {
        /* bail if we've read everything in this run */
        if (instream->tell(instream) >= end) {
            /* make sure we haven't read too much */
            if (instream->tell(instream) > end) {
                UV pos = instream->tell(instream);
                Kino_confess(
                    "read past end of run: %"UVuf", %"UVuf, pos, (UV)end );
            }
            break;
        }

        /* bail if we've hit the ceiling for this run's cache */
        if (run_cache_bytes > run_cache_limit)
            break;

        /* retrieve and decode len */
        len = instream->read_vint(instream);

        /* recover the stringified scalar */
        scratch_sv = newSV(len + 1);
        SvCUR_set(scratch_sv, len);
        SvPOK_on(scratch_sv);
        *SvEND(scratch_sv) = '\0';
        read_buf = SvPVX(scratch_sv);
        instream->read_bytes(instream, read_buf, len);

        /* add to the run's cache */
        av_push(run_cache_av, scratch_sv);

        /* track how much we've read so far */
        num_items++;
        run_cache_bytes += len + 1 + KINO_PER_ITEM_OVERHEAD;
    }

    run->pos = instream->tell(instream);

    return num_items;
}

static void
Kino_SortEx_refill_cache(SortExternal *sortex) {
    SV        *endpost_sv;
    SortExRun *run;
    I32        i = 0;
    
    /* make sure all runs have at least one item */
    while (i < sortex->num_runs) {
        run = sortex->runs[i];
        if (Kino_SortEx_refill_run(sortex, run)) {
            i++;
        }
        else {
            Kino_SortEx_destroy_run(run);
            sortex->num_runs--;
            sortex->runs[i] = sortex->runs[ sortex->num_runs ];
            sortex->runs[ sortex->num_runs ] = NULL;
        }
    }

    if (!sortex->num_runs)
        return;

    /* move as many items as possible into the sorting cache */
    endpost_sv = Kino_SortEx_find_endpost(sortex);
    for (i = 0; i < sortex->num_runs; i++) {
        Kino_SortEx_gatekeeper(sortex, sortex->runs[i], endpost_sv);
    }
    SvREFCNT_dec(endpost_sv);

    Kino_SortEx_sort_cache(sortex);
}

static SV*
Kino_SortEx_find_endpost(SortExternal *sortex) {
    int         i, max, max_index;
    SV         *endpost_sv;
    SortExRun  *run;
    AV         *run_cache_av;
    SV        **sv_ptr;

    endpost_sv = newSV(0);

    max = sortex->num_runs;
    for (i = 0; i < max; i++) {
        run_cache_av = sortex->runs[i]->cache;
        max_index = av_len(run_cache_av);
        if (max_index == -1)
            continue;
        sv_ptr = av_fetch(run_cache_av, max_index, 0);
        if (sv_ptr == NULL)
            Kino_confess("find_endpost: NULL SV");
        if (i == 0) {
            SvSetSV(endpost_sv, *sv_ptr);
            continue;
        }
        if (Kino_StrHelp_compare_svs(*sv_ptr, endpost_sv) < 0)
            SvSetSV(endpost_sv, *sv_ptr);
    }

    return endpost_sv;
}

static void
Kino_SortEx_gatekeeper(SortExternal *sortex, SortExRun *run, SV *endpost_sv) {
    AV  *sortex_cache_av, *run_cache_av;
    I32  max_index;
    SV  *item_sv;

    /* local copies */
    sortex_cache_av = sortex->cache;
    run_cache_av    = run->cache;

    max_index = Kino_SortEx_find_max_in_range(run_cache_av, endpost_sv);
    for(max_index; max_index >= 0; max_index--) {
        item_sv = av_shift(run_cache_av);
        av_push(sortex_cache_av, item_sv);
    }
}

/* Return the highest index for an item in the run's cache which is lexically
 * less than or equal to the endpost.
 */
static I32
Kino_SortEx_find_max_in_range(AV *cache_av, SV *endpost_sv) {
    I32 lo, mid, hi, delta;
    SV **candidate_sv_ptr;

    lo  = -1;
    hi = av_len(cache_av) + 1; 
    mid = 0;

    /* binary search */
    while (hi - lo > 1) {
        mid = (lo + hi) >> 1;
        candidate_sv_ptr = av_fetch(cache_av, mid, 0);
        if (candidate_sv_ptr == NULL)
            Kino_confess("find_num_in_range: NULL SV");
        delta = Kino_StrHelp_compare_svs(*candidate_sv_ptr, endpost_sv);
        if (delta > 0) 
			hi = mid;
        else
			lo = mid;
    }
    return lo;
}

void
Kino_SortEx_destroy(SortExternal *sortex) {
    I32 i;
    SvREFCNT_dec((SV*)sortex->cache);
    SvREFCNT_dec(sortex->outstream_sv);
    SvREFCNT_dec(sortex->instream_sv);
    SvREFCNT_dec(sortex->invindex_sv);
    SvREFCNT_dec(sortex->seg_name_sv);
    for (i = 0; i < sortex->num_runs; i++) {
        Kino_SortEx_destroy_run(sortex->runs[i]);
    }
    Kino_Safefree(sortex->runs);
    Kino_Safefree(sortex);
}

static void
Kino_SortEx_destroy_run(SortExRun *run) {
    SvREFCNT_dec(run->cache);
    Kino_Safefree(run);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::SortExternal - external sorting

=head1 DESCRIPTION

External sorting implementation, using lexical comparison.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut
