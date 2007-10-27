use strict;
use warnings;

package KinoSearch::Search::HitQueue;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::PriorityQueue );

our %instance_vars = (
    # params
    max_size => undef,
);

use KinoSearch::Search::ScoreDoc;

# Create an array of ScoreDoc objects.
sub score_docs { shift->pop_all }

sub insert_score_doc {
    my ( $self, $score_doc ) = @_;
    return $self->insert($score_doc);
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::HitQueue

kino_HitQueue*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::HitQueue::instance_vars");
    chy_u32_t max_size = extract_uv(args_hash, SNL("max_size"));

    /* create object */
    RETVAL = kino_HitQ_new(max_size);
}
OUTPUT: RETVAL


chy_bool_t
insert(self, score_doc)
    kino_HitQueue *self;
    kino_ScoreDoc *score_doc;
CODE:
    REFCOUNT_INC(score_doc);
    RETVAL = Kino_HitQ_Insert(self, score_doc);
OUTPUT: RETVAL

SV*
pop(self)
    kino_HitQueue *self;
CODE:
{
    kino_ScoreDoc *score_doc = (kino_ScoreDoc*)Kino_HitQ_Pop(self);
    if (score_doc == NULL) {
        RETVAL = &PL_sv_undef;
    }
    else {
        RETVAL = kobj_to_pobj(score_doc);
    }
    REFCOUNT_DEC(score_doc);
}
OUTPUT: RETVAL

void
pop_all(self)
    kino_HitQueue *self;
PPCODE:
{
    AV* out_av = newAV();
    
    if (self->size > 0) {
        chy_i32_t i;

        /* map the queue nodes onto the array in reverse order */
        av_extend(out_av, self->size - 1);
        for (i = self->size - 1; i >= 0; i--) {
            kino_ScoreDoc *const score_doc 
                = (kino_ScoreDoc*)Kino_HitQ_Pop(self);
            SV *const score_doc_sv = kobj_to_pobj(score_doc);
            REFCOUNT_DEC(score_doc);
            av_store(out_av, i, score_doc_sv);
        }
    }
    XPUSHs( sv_2mortal(newRV_noinc( (SV*)out_av )) );
    XSRETURN(1);
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::HitQueue - Track highest scoring docs.

=head1 DESCRIPTION 

HitQueue, a subclass of KinoSearch::Util::PriorityQueue, keeps track of
score/doc_num pairs.  Each pair is stored in a single scalar, with the
document number in the PV and the score in the NV.
The encoding algorithm is functionally equivalent to this:

    my $encoded_doc_num = pack('N', $doc_num);
    my $doc_num_slash_score = dualvar( $score, $encoded_doc_num );

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
