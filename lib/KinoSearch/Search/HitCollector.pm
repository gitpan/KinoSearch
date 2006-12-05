package KinoSearch::Search::HitCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass );

# all xs, other than the pragmas/includes

package KinoSearch::Search::HitQueueCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        size => undef,
    );
}
our %instance_vars;

use KinoSearch::Search::HitQueue;

sub new {
    my $self = shift->SUPER::new;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = @_;
    croak("Required parameter: 'size'") unless defined $args{size};

    my $hit_queue
        = KinoSearch::Search::HitQueue->new( max_size => $args{size} );
    $self->_set_storage($hit_queue);
    $self->_define_collect;

    return $self;
}

*get_total_hits = *KinoSearch::Search::HitCollector::get_i;
*get_hit_queue  = *KinoSearch::Search::HitCollector::get_storage;

sub get_max_size {
    shift->get_hit_queue->get_max_size;
}

package KinoSearch::Search::BitCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        capacity => 0,
    );
}
our %instance_vars;

use KinoSearch::Util::BitVector;

sub new {
    my $self = shift->SUPER::new;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    my $bit_vec
        = KinoSearch::Util::BitVector->new( capacity => $args{capacity} );
    $self->_set_storage($bit_vec);
    $self->_define_collect;

    return $self;
}

*get_bit_vector = *KinoSearch::Search::HitCollector::get_storage;

package KinoSearch::Search::FilteredCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

BEGIN {
    __PACKAGE__->init_instance_vars(
        hit_collector => undef,
        filter_bits   => undef,
    );
}
our %instance_vars;

sub new {
    my $self = shift->SUPER::new;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = @_;
    croak("Required parameter: 'hit_collector'")
        unless a_isa_b( $args{hit_collector},
        "KinoSearch::Search::HitCollector" );

    $self->_set_filter_bits( $args{filter_bits} );
    $self->_set_storage( $args{hit_collector} );
    $self->_define_collect;

    return $self;
}

package KinoSearch::Search::OffsetCollector;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

BEGIN {
    __PACKAGE__->init_instance_vars(
        hit_collector => undef,
        offset        => undef,
    );
}
our %instance_vars;

sub new {
    my $self = shift->SUPER::new;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = @_;
    croak("Required parameter: 'hit_collector'")
        unless a_isa_b( $args{hit_collector},
        "KinoSearch::Search::HitCollector" );

    $self->_set_f( $args{offset} );
    $self->_set_storage( $args{hit_collector} );
    $self->_define_collect;

    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitCollector

void
new(either_sv)
    SV *either_sv;
PREINIT:
    char         *class;
    HitCollector *hc;
PPCODE:
    hc    = Kino_HC_new();
    class = sv_isobject(either_sv) 
        ? sv_reftype(either_sv, 0)
        : SvPV_nolen(either_sv);
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)hc);
    XSRETURN(1);

=begin comment

    $hit_collector->collect( $doc_num, $score );

Process a doc_num/score combination.  In production, this method should not be
called from Perl, as collecting hits is an extremely data-intensive operation.

=end comment
=cut

void
collect(hc, doc_num, score)
    HitCollector *hc;
    U32           doc_num;
    float         score;
PPCODE:
    hc->collect(hc, doc_num, score);

SV* 
_set_or_get(hc, ...)
    HitCollector *hc;
ALIAS:
    _set_storage     = 1
    get_storage      = 2
    _set_i           = 3
    get_i            = 4
    _set_f           = 5
    _get_f           = 6
    _set_filter_bits = 7
    _get_filter_bits = 8
CODE:
{
    KINO_START_SET_OR_GET_SWITCH
    
    case 1:  SvREFCNT_dec(hc->storage_ref);
             hc->storage_ref = newSVsv( ST(1) );
             Kino_extract_anon_struct(hc->storage_ref, hc->storage);
             /* fall through */
    case 2:  RETVAL = newSVsv(hc->storage_ref);
             break;

    case 3:  hc->i = SvUV( ST(1) );
             /* fall through */
    case 4:  RETVAL = newSVuv(hc->i);
             break;

    case 5:  hc->f = SvNV( ST(1) );
             /* fall through */
    case 6:  RETVAL = newSVnv(hc->f);
             break;
             
    case 7:  SvREFCNT_dec(hc->filter_bits_ref);
             hc->filter_bits_ref = newSVsv( ST(1) );
             Kino_extract_struct( hc->filter_bits_ref, hc->filter_bits, 
                BitVector*, "KinoSearch::Util::BitVector" );
             /* fall through */
    case 8:  RETVAL = newSVsv(hc->filter_bits_ref);
             break;

    KINO_END_SET_OR_GET_SWITCH
}
OUTPUT: RETVAL

void
DESTROY(hc)
    HitCollector *hc;
PPCODE:
    Kino_HC_destroy(hc);


MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitQueueCollector

void
_define_collect(hc)
    HitCollector *hc;
PPCODE:
    hc->collect = Kino_HC_collect_HitQueue;

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::BitCollector

void
_define_collect(hc)
    HitCollector *hc;
PPCODE:
    hc->collect = Kino_HC_collect_BitVec;

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::FilteredCollector

void
_define_collect(hc);
    HitCollector *hc;
PPCODE:
    hc->collect = Kino_HC_collect_filtered;

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::OffsetCollector

void
_define_collect(hc);
    HitCollector *hc;
PPCODE:
    hc->collect = Kino_HC_collect_offset;



__H__

#ifndef H_KINO_HIT_COLLECTOR
#define H_KINO_HIT_COLLECTOR 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilMathUtils.h"
#include "KinoSearchUtilBitVector.h"
#include "KinoSearchUtilPriorityQueue.h"
#include "KinoSearchUtilMemManager.h"

typedef struct hitcollector {
    void      (*collect)(struct hitcollector*, U32, float);
    float       f;
    U32         i;
    void       *storage;
    SV         *storage_ref;
    BitVector  *filter_bits;
    SV         *filter_bits_ref;
} HitCollector;

HitCollector* Kino_HC_new();
void Kino_HC_collect_death(HitCollector*, U32, float);
void Kino_HC_collect_HitQueue(HitCollector*, U32, float);
void Kino_HC_collect_BitVec(HitCollector*, U32, float);
void Kino_HC_collect_filtered(HitCollector*, U32, float);
void Kino_HC_collect_offset(HitCollector*, U32, float);
void Kino_HC_destroy(HitCollector*);

#endif /* include guard */

__C__


#include "KinoSearchSearchHitCollector.h"

HitCollector*
Kino_HC_new() {
    HitCollector  *hc;

    /* allocate memory and init */
    Kino_New(0, hc, 1, HitCollector);
    hc->f               = 0;
    hc->i               = 0;
    hc->storage         = NULL;
    hc->storage_ref     = &PL_sv_undef;
    hc->filter_bits     = NULL;
    hc->filter_bits_ref = &PL_sv_undef;

    /* force the subclass to spec a collect method */
    hc->collect = Kino_HC_collect_death;

    return hc;
}

void
Kino_HC_collect_death(HitCollector *hc, U32 doc_num, float score) {
    Kino_confess("hit_collector->collect must be assigned in a subclass");
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

void
Kino_HC_collect_BitVec(HitCollector *hc, U32 doc_num, float score) {
    BitVector *bit_vec;
    bit_vec = (BitVector*)hc->storage;

    /* add to the total number of hits */
    hc->i++;

    /* add the doc_num to the BitVector */
    Kino_BitVec_set(bit_vec, doc_num);
}

void
Kino_HC_collect_filtered(HitCollector *hc, U32 doc_num, float score) {
    if (hc->filter_bits == NULL) {
        Kino_confess("filter_bits not set on FilteredCollector");
    }

    if (Kino_BitVec_get(hc->filter_bits, doc_num)) {
        HitCollector *inner_collector;
        inner_collector = (HitCollector*)hc->storage;
        inner_collector->collect(inner_collector, doc_num, score);
    }
}

void
Kino_HC_collect_offset(HitCollector *hc, U32 doc_num, float score) {
    HitCollector *inner_collector = (HitCollector*)hc->storage;
    U32 offset_doc_num = doc_num + hc->f;
    inner_collector->collect(inner_collector, offset_doc_num, score);
}


void
Kino_HC_destroy(HitCollector *hc) {
    SvREFCNT_dec(hc->storage_ref);
    SvREFCNT_dec(hc->filter_bits_ref);
    Kino_Safefree(hc);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::HitCollector - process doc/score pairs

=head1 DESCRIPTION

A Scorer spits out raw doc_num/score pairs; a HitCollector decides what to do
with them, based on the hc->collect method.

A HitQueueCollector keeps the highest scoring N documents and their associated
scores in a HitQueue while iterating through a large list.

A BitCollector builds a BitVector with a set bit for each doc number (scores
are irrelevant).

A FilterCollector wraps another HitCollector, only allowing the inner
collector to "see" doc_num/score pairs which make it through the filter.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.15.

=end devdocs
=cut


