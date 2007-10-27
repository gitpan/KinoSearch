use strict;
use warnings;

package KinoSearch::Index::PostingList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %make_scorer_defaults = (
    weight       => undef,
    weight_value => undef,
    similarity   => undef,
);

sub close { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PostingList

void
seek(self, term_sv)
    kino_PostingList *self;
    SV *term_sv;
PPCODE:
{
    kino_Term *target = NULL;
    MAYBE_EXTRACT_STRUCT(term_sv, target, kino_Term*, 
        "KinoSearch::Index::Term");
    Kino_PList_Seek(self, target);
}

bool
next(self)
    kino_PostingList *self;
CODE:
    RETVAL = Kino_PList_Next(self);
OUTPUT: RETVAL

bool
skip_to(self, target)
    kino_PostingList *self;
    chy_u32_t target;
CODE:
    RETVAL = Kino_PList_Skip_To(self, target);
OUTPUT: RETVAL

kino_Posting*
get_posting(self)
    kino_PostingList *self;
CODE:
    RETVAL = Kino_PList_Get_Posting(self);
    REFCOUNT_INC(RETVAL);
OUTPUT: RETVAL

chy_u32_t
get_doc_num(self);
    kino_PostingList *self;
CODE:
    RETVAL = Kino_PList_Get_Doc_Num(self);
OUTPUT: RETVAL

chy_u32_t
get_doc_freq(self)
    kino_PostingList *self;
CODE:
    RETVAL = Kino_PList_Get_Doc_Freq(self);
OUTPUT: RETVAL

kino_Scorer*
make_scorer(self, ...)
    kino_PostingList *self;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::PostingList::make_scorer_defaults");
    SV *weight_sv = extract_sv(args_hash, SNL("weight"));
    kino_Similarity *sim = (kino_Similarity*)extract_obj(args_hash, 
        SNL("similarity"), "KinoSearch::Search::Similarity");
    float weight_val = extract_nv(args_hash, SNL("weight_value"));
    RETVAL = Kino_PList_Make_Scorer(self, sim, weight_sv, weight_val);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Index::PostingList - Term-Document pairings

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

