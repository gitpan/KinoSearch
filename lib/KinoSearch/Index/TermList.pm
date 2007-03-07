use strict;
use warnings;

package KinoSearch::Index::TermList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN { __PACKAGE__->init_instance_vars(); }

our %build_sort_cache_args = (
    term_docs => undef,
    max_doc   => undef,
);
use KinoSearch::Util::IntMap;
use KinoSearch::Index::TermDocs;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::TermList

void
seek(self, term_sv)
    kino_TermList *self;
    SV *term_sv;
PPCODE:
{
    kino_Term *term = NULL;
    MAYBE_EXTRACT_STRUCT(term_sv, term, kino_Term*,
        "KinoSearch::Index::Term");
    Kino_TermList_Seek(self, term);
}

IV
next(self)
    kino_TermList *self;
CODE:
    RETVAL = Kino_TermList_Next(self);
OUTPUT: RETVAL

void
reset(self)
    kino_SegTermList *self;
PPCODE:
    Kino_SegTermList_Reset(self);

kino_i32_t
get_term_num(self);
    kino_TermList *self;
CODE:
    RETVAL = Kino_TermList_Get_Term_Num(self);
OUTPUT: RETVAL

SV*
get_term(self);
    kino_TermList *self;
CODE:
{
    kino_Term *term = Kino_TermList_Get_Term(self);
    if (term == NULL) {
        RETVAL = newSV(0);
    }
    else {
        RETVAL = kobj_to_pobj(term);
    }
}
OUTPUT: RETVAL

kino_IntMap*
build_sort_cache(self, ...)
    kino_TermList *self;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::TermList::build_sort_cache_args");
    kino_TermDocs *term_docs = extract_obj(args_hash, SNL("term_docs"), 
        "KinoSearch::Index::TermDocs");
    kino_u32_t max_doc = extract_uv(args_hash, SNL("max_doc"));

    RETVAL = Kino_TermList_Build_Sort_Cache(self, term_docs, max_doc);
}
OUTPUT: RETVAL

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermList - Scan through a list of Terms.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Conceptually, a TermList is a array of Term => TermInfo pairs, sorted
first by field number, then term sort order.  The implementations in
KinoSearch solve the same problem that tied arrays solve: it is possible to
iterate through the array while loading as little as possible into memory.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut



