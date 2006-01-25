package KinoSearch::Search::HitQueue;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::PriorityQueue );

use KinoSearch::Search::HitDoc;

our %instance_vars = __PACKAGE__->init_instance_vars();

# Create an array of "empty" HitDoc objects -- they have scores and doc_nums,
# but the stored fields have yet to be retrieved.
sub hit_docs {
    my $self = shift;

    # decode score/doc_num scalars into HitDocs
    my @hit_docs = map {
        KinoSearch::Search::HitDoc->new(
            doc_num => unpack( 'N', "$_" ),
            score   => 0 + $_,
            )
    } @{ $self->pop_all };

    return \@hit_docs;
}

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitQueue

void
define_less_than(obj)
    PriorityQueue *obj;
PPCODE:
    obj->less_than = &Kino_HitQ_less_than;

__H__

#ifndef H_KINOSEARCH_SEARCH_HIT_QUEUE
#define H_KINOSEARCH_SEARCH_HIT_QUEUE 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

bool Kino_HitQ_less_than(SV*, SV*);

#endif /* include guard */

__C__

#include "KinoSearchSearchHitQueue.h"

/* Compare the NV then the PV for two scalars. 
 */
bool
Kino_HitQ_less_than(SV* a, SV* b) {
    char *ptr_a, *ptr_b; 

    if (SvNV(a) == SvNV(b)) {
        ptr_a = SvPVX(a);
        ptr_b = SvPVX(b);
        /* sort by doc_num second */
        return (bool)memcmp(ptr_b, ptr_a, 4);
    }
    /* sort by score first */
    return SvNV(a) < SvNV(b);
}


__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::HitQueue - track highest scoring docs

=head1 DESCRIPTION 

HitQueue, a subclass of KinoSearch::Util::PriorityQueue, keeps track of
score/doc_num pairs.  Each pair is stored in a single scalar, with the
document number in the PV and the score in the NV.
The encoding algorithm is functionally equivalent to this:

    my $encoded_doc_num = pack('N', $doc_num);
    my $doc_num_slash_score = dualvar( $score, $encoded_doc_num );

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut
