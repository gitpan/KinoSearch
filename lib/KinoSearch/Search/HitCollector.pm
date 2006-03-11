package KinoSearch::Search::HitCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars( storage => undef, );

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    verify_args( \%instance_vars, @_ );
    my %args = @_;
    confess "Missing required param 'storage'"
        unless defined $args{storage};
    my $self = _new( $class, $args{storage} );

    $self->define_collect;
    return $self;
}

# Define the C pointer-to-function hc->collect.
sub define_collect { shift->abstract_death }

package KinoSearch::Search::HitQueueCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

use KinoSearch::Search::HitQueue;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args
    size => undef,
);

sub new {
    my $class = shift;
    verify_args( \%instance_vars, @_ );
    my %args = @_;
    croak("Required parameter: 'size'") unless defined $args{size};

    my $hit_queue
        = KinoSearch::Search::HitQueue->new( max_size => $args{size} );
    return $class->SUPER::new( storage => $hit_queue );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitCollector

void
_new(class, storage_ref)
    char  *class;
    SV    *storage_ref;
PREINIT:
    HitCollector *obj;
PPCODE:
    obj   = Kino_HC_new(storage_ref);
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)obj);
    XSRETURN(1);

=begin comment

    $hit_collector->collect( $doc_num, $score );

Process a doc_num/score combination.  In production, this method should not be
called, as collecting hits is an extremely data-intensive operation.  Instead,
the underlying C pointer-to-function should be called from within a Scorer's C
loop.

=end comment
=cut

void
collect(obj, doc_num, score)
    HitCollector *obj;
    U32           doc_num;
    float         score;
PPCODE:
    obj->collect(obj, doc_num, score);

SV* 
_set_or_get(obj, ...)
    HitCollector *obj;
ALIAS:
    get_storage = 2
    get_i       = 4
CODE:
{
    switch (ix) {

    case 2:  RETVAL = newSVsv(obj->storage_ref);
             break;

    case 4:  RETVAL = newSVuv(obj->i);
             break;

    default: Kino_confess("Internal error: _set_or_get ix: %d", ix); 
    }
}
OUTPUT: RETVAL

void
DESTROY(obj)
    HitCollector *obj;
PPCODE:
    SvREFCNT_dec(obj->storage_ref);
    Kino_Safefree(obj);


MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitQueueCollector

void
define_collect(obj)
    HitCollector *obj;
PPCODE:
    obj->collect = Kino_HC_collect_HitQueue;


__H__

#ifndef H_KINO_HIT_COLLECTOR
#define H_KINO_HIT_COLLECTOR 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilEndianUtils.h"
#include "KinoSearchUtilPriorityQueue.h"
#include "KinoSearchUtilMemManager.h"

typedef struct hitcollector {
    void  (*collect)(struct hitcollector*, U32, float);
    float   f;
    U32     i;
    void   *storage;
    SV     *storage_ref;
} HitCollector;

/* Allocate a new HitCollector.  obj->collect will still have to be set, as
 * the default just throws an error. */
HitCollector* Kino_HC_new(SV*);

/* A placeholder which throws an error. */
void Kino_HC_collect_death(HitCollector*, U32, float);
    
/* Collect hits into a HitQueue. */
void Kino_HC_collect_HitQueue(HitCollector*, U32, float);

#endif /* include guard */

__C__


#include "KinoSearchSearchHitCollector.h"

HitCollector*
Kino_HC_new (SV* storage_ref) {
    HitCollector  *obj;

    /* allocate memory and init */
    Kino_New(0, obj, 1, HitCollector);
    obj->f = 0;
    obj->i = 0;

    /* store storage object, so Perl can deal with gc at DESTROY-time */
    obj->storage_ref = storage_ref;
    SvREFCNT_inc(storage_ref);

    /* deref the storage object */
    obj->storage = INT2PTR(void*,( SvIV((SV*)SvRV(storage_ref)) ) );
    
    /* force the subclass to spec a collect method */
    obj->collect = Kino_HC_collect_death;

    return obj;
}

void
Kino_HC_collect_death(HitCollector *hc, U32 doc_num, float score) {
    Kino_confess("Must assign new C pointer-to-function to 'collect'");
}


void
Kino_HC_collect_HitQueue(HitCollector *hc, U32 doc_num, float score) {
    /* add to the total number of hits */
    hc->i++;
    
    /* bail if the score doesn't exceed the minimum */
    if (score < hc->f) {
        return;
    }
    else {
        SV *element;
        char doc_num_buf[4];
        PriorityQueue *hit_queue;
        hit_queue = (PriorityQueue*)hc->storage;

        /* put a dualvar scalar -- encoded doc_num in PV, score in NV */ 
        element = sv_newmortal();
        (void)SvUPGRADE(element, SVt_PVNV);
        Kino_encode_bigend_U32(doc_num, &doc_num_buf);
        sv_setpvn(element, doc_num_buf, (STRLEN)4);
        SvNV_set(element, (double)score);
        SvNOK_on(element);
        (void)Kino_PriQ_insert(hit_queue, element);

        /* store the bubble score in a more accessible spot */
        if (hit_queue->size == hit_queue->max_size) {
            SV *least_sv;
            least_sv = Kino_PriQ_peek(hit_queue);
            hc->f    = SvNV(least_sv);
        }
    }
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::HitCollector - process doc/score pairs

=head1 DESCRIPTION

A Scorer spits out raw doc_num/score pairs; a HitCollector decides what to do
with them, based on the C pointer-to-function hc->collect, which is set when
the constructor calls $self->define_collect.

A HitQueueCollector keeps the highest scoring N documents and their associated
scores in a HitQueue while iterating through a large list.

=head1 TODO

Implement BitSetCollector.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.08.

=end devdocs
=cut


