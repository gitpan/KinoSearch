package KinoSearch::Util::PriorityQueue;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        max_size => undef,
    );
}

1;

__END__

__XS__

MODULE =  KinoSearch    PACKAGE = KinoSearch::Util::PriorityQueue

void
new(either_sv, ...)
    SV *either_sv;
PREINIT:
    char          *class;
    HV            *args_hash;
    U32            max_size;
    PriorityQueue *pq;
PPCODE:
    /* determine the class */
    class = sv_isobject(either_sv) 
        ? sv_reftype(either_sv, 0) 
        : SvPV_nolen(either_sv);
        
    /* process hash-style params */
    Kino_Verify_build_args_hash(args_hash, 
        "KinoSearch::Util::PriorityQueue::instance_vars", 1);
    max_size = (U32)SvUV( Kino_Verify_extract_arg(args_hash, "max_size", 8) );

    /* build object */
    pq    = Kino_PriQ_new(max_size);
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)pq);
    XSRETURN(1);

=for comment

Add an element to the Queue if either...
a) the queue isn't full, or
b) the element belongs in the queue and should displace another

=cut

void
insert(pq, element)
    PriorityQueue *pq;
    SV             *element;
PPCODE:
    Kino_PriQ_insert(pq, element);


=for comment

Pop the *least* item off of the priority queue.

=cut

SV*
pop(pq)
    PriorityQueue *pq;
CODE:
    RETVAL = Kino_PriQ_pop(pq);
    if (RETVAL == Nullsv) {
        RETVAL = &PL_sv_undef;
    }
    else {
        RETVAL = newSVsv(RETVAL);
    }
OUTPUT: RETVAL


=for comment

Return the least item in the queue, but don't remove it.

=cut

SV*
peek(pq)
    PriorityQueue *pq;
CODE:
    RETVAL = Kino_PriQ_peek(pq);
    if (RETVAL == Nullsv) {
        RETVAL = &PL_sv_undef;
    }
    else {
        RETVAL = newSVsv(RETVAL);
    }
OUTPUT: RETVAL



=for comment

Empty the queue into an array, with the highest priority item at index 0. 

=cut

void
pop_all(pq)
    PriorityQueue *pq;
PREINIT:
    AV* out_av;
PPCODE:
    out_av = Kino_PriQ_pop_all(pq);
    XPUSHs( sv_2mortal(newRV_noinc( (SV*)out_av )) );


SV*
_set_or_get(pq, ...)
    PriorityQueue *pq;
ALIAS:
    get_size      = 2
    get_max_size  = 4
CODE:
{
    KINO_START_SET_OR_GET_SWITCH

    case 2:  RETVAL = newSVuv(pq->size);
             break;

    case 4:  RETVAL = newSVuv(pq->max_size);
             break;

    KINO_END_SET_OR_GET_SWITCH
}
OUTPUT: RETVAL


void
DESTROY(pq)
    PriorityQueue *pq;
PPCODE:
    Kino_PriQ_destroy(pq);

__H__

#ifndef H_KINOSEARCH_UTIL_PRIORITY_QUEUE
#define H_KINOSEARCH_UTIL_PRIORITY_QUEUE 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilMemManager.h"

typedef struct priorityqueuec {
    U32          size;
    U32          max_size;
    SV         **heap;
    bool       (*less_than)(SV*, SV*);
} PriorityQueue;

PriorityQueue* Kino_PriQ_new (U32 max_size);
bool Kino_PriQ_insert(PriorityQueue*, SV*);
SV*  Kino_PriQ_pop(PriorityQueue*);
SV*  Kino_PriQ_peek(PriorityQueue*);
AV*  Kino_PriQ_pop_all(PriorityQueue*);
void Kino_PriQ_destroy(PriorityQueue*);
bool Kino_PriQ_default_less_than( SV*, SV* );
void Kino_PriQ_dump(PriorityQueue*);

#endif /* include guard */


__C__

#include "KinoSearchUtilPriorityQueue.h"

static void Kino_PriQ_put(PriorityQueue*, SV*);
static SV*  Kino_PriQ_top(PriorityQueue*);
static void Kino_PriQ_adjust_top(PriorityQueue*);
static void Kino_PriQ_clear(PriorityQueue*);
static void Kino_PriQ_up_heap(PriorityQueue*);
static void Kino_PriQ_down_heap(PriorityQueue*);

PriorityQueue*
Kino_PriQ_new (U32 max_size) {
    PriorityQueue *pq;
    U32 i, heap_size;

    Kino_New(0, pq, 1, PriorityQueue);

    pq->size = 0;
    pq->max_size = max_size;
    pq->less_than = Kino_PriQ_default_less_than;

    /* allocate space for the heap, assign all slots to Nullsv */
    heap_size = max_size + 1;
    Kino_New(0, pq->heap, heap_size, SV*);
    for (i = 0; i < heap_size; i++) {
        pq->heap[i] = Nullsv;
    }

    return pq;
}

/* Add an element to the heap.  Throw an error if too many elements 
 * are added.
 */
static void
Kino_PriQ_put(PriorityQueue *pq, SV *element) {
    /* extend heap */
    if (pq->size >= pq->max_size) {
        Kino_confess("PriorityQueue exceeded max_size: %d %d", 
            pq->size, pq->max_size);
    }
    pq->size++;

    /* put element into heap */
    pq->heap[ pq->size ] = newSVsv(element);

    /* adjust heap */
    Kino_PriQ_up_heap(pq);
}

bool
Kino_PriQ_insert(PriorityQueue *pq, SV *element) {
    SV *scratch_sv; 

    /* absorb element if there's a vacancy */
    if (pq->size < pq->max_size) {
        Kino_PriQ_put(pq, element);
        return 1;
    }
    /* otherwise, compete for the slot */
    else {
        scratch_sv = Kino_PriQ_top(pq);
        if( pq->size > 0 && !pq->less_than(element, scratch_sv)) {
            /* if the new element belongs in the queue, replace something */
            scratch_sv = pq->heap[1];
            SvREFCNT_dec(scratch_sv);
            pq->heap[1] = newSVsv(element);
            Kino_PriQ_adjust_top(pq);
            return 1;
        }
        else {
            return 0;
        }
    }
}

/* Return the least item in the queue, or Nullsv if queue is empty. 
 */
static SV*
Kino_PriQ_top(PriorityQueue *pq) {
    if (pq->size > 0) {
        return pq->heap[1]; /* note: no refcount manip */
    }
    else {
        return Nullsv;
    }
}

SV*
Kino_PriQ_pop(PriorityQueue *pq) {
    SV *result;

    if (pq->size > 0) {
        /* mortalize the first value and save it */
        result = sv_2mortal( pq->heap[1] );

        /* move last to first and adjust heap */
        pq->heap[1] = pq->heap[ pq->size ];
        pq->heap[ pq->size ] = Nullsv;
        pq->size--;
        Kino_PriQ_down_heap(pq);

        return result;
    }
    else {
        return Nullsv;
    }
}

SV*
Kino_PriQ_peek(PriorityQueue *pq) {
    if (pq->size > 0) {
        return pq->heap[1];
    }
    else {
        return Nullsv;
    }
}

AV*
Kino_PriQ_pop_all(PriorityQueue *pq) {
    AV* out_av;
    I32 i;
    SV* element;
    
    /* allocate an empty AV; return immediately if the queue is empty */
    out_av = newAV();
    if (pq->size == 0) {
        return out_av;
    }

    /* map the queue nodes onto the array in reverse order */
    av_extend(out_av, pq->size - 1);
    for (i = pq->size - 1; i >= 0; i--) {
        element = newSVsv( Kino_PriQ_pop(pq) );
        av_store(out_av, i, element);
    }
    return out_av;
}

/* Alias for down_heap.  Should be called when the item at the top changes. 
 */
static void
Kino_PriQ_adjust_top(PriorityQueue *pq) {
    Kino_PriQ_down_heap(pq);
}

/* Free all the elements in the heap and set size to 0.
 */
static void 
Kino_PriQ_clear(PriorityQueue *pq) {
    U32 i;
    SV **sv_ptr;

    sv_ptr = (pq->heap + 1);
    /* node 0 is held empty, to make the algo clearer */
    for (i = 1; i <= pq->size; i++) {
        SvREFCNT_dec(*sv_ptr);
        *sv_ptr = Nullsv;
        sv_ptr++;
    }   
    pq->size = 0;
}

/* Heap adjuster. 
 */
static void
Kino_PriQ_up_heap(PriorityQueue *pq) {
    U32 i, j;
    SV *node;

    i = pq->size;
    node = pq->heap[i]; /* save bottom node */
    j = i >> 1;
    while (    j > 0 
            && pq->less_than(node, pq->heap[j])
    ) {
        pq->heap[i] = pq->heap[j];
        i = j;
        j = j >> 1;
    }
    pq->heap[i] = node;
}

/* Heap adjuster.
 */
static void
Kino_PriQ_down_heap(PriorityQueue *pq) {
    U32 i, j, k;
    SV *node;

    /* save top node */
    i = 1;
    node = pq->heap[i]; 
    
    /* find smaller child */
    j = i << 1;
    k = j + 1;
    if (   k <= pq->size 
        && pq->less_than(pq->heap[k], pq->heap[j])
    ) {
        j = k;
    }

    while (   j <= pq->size 
           && pq->less_than(pq->heap[j], node)
    ) {
        pq->heap[i] = pq->heap[j];
        i = j;
        j = i << 1;
        k = j + 1;
        if (   k <= pq->size 
            && pq->less_than(pq->heap[k], pq->heap[j])
        ) {
            j = k;
        }
    }
    pq->heap[i] = node;
}

/* Compare the integer values of two scalars. 
 */
bool
Kino_PriQ_default_less_than(SV* a, SV* b) {
    if ( SvIV(a) < SvIV(b) ) {
        return 1;
    }
    else {
        return 0;
    }
}

void
Kino_PriQ_destroy(PriorityQueue *pq) {
    Kino_PriQ_clear(pq);
    Kino_Safefree(pq->heap);
    Kino_Safefree(pq);
}

/* Print integer values for all items in the Queue. */
void
Kino_PriQ_dump(PriorityQueue *pq) {
    U32 i;
    SV **sv_ptr;

    sv_ptr = (pq->heap + 1);
    for (i = 1; i <= pq->size; i++) {
        IV j = SvIV(*sv_ptr);
        fprintf(stderr, "%"IVdf" ", j);
        sv_ptr++;
    }   
    fprintf(stderr, "\n");
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::PriorityQueue - classic heap sort / priority queue 

=head1 DESCRIPTION

PriorityQueue implements a textbook heap-sort/priority-queue algorithm.  This
particular variant leaves slot 0 in the queue open in order to keep the
relationship between node rank and index clear in the up_heap and down_heap
routines.

The nodes in this implementation are all perl scalars, which allows us to use
Perl's reference counting to manage memory.  However, the underlying queue
management methods are all written in C, which allows them to be used within
other C routines without expensive callbacks to Perl. 

Subclass constructors must redefine the C pointer-to-function, less_than. The
default behavior is to compare the SvIV value of two scalars.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.14.

=end devdocs
=cut

