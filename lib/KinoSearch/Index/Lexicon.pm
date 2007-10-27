use strict;
use warnings;

package KinoSearch::Index::Lexicon;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %build_sort_cache_args = (
    # params
    posting_list => undef,
    max_doc      => undef,
);
use KinoSearch::Util::IntMap;
use KinoSearch::Index::PostingList;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::Lexicon

void
seek(self, term_sv)
    kino_Lexicon *self;
    SV *term_sv;
PPCODE:
{
    kino_Term *term = NULL;
    MAYBE_EXTRACT_STRUCT(term_sv, term, kino_Term*,
        "KinoSearch::Index::Term");
    Kino_Lex_Seek(self, term);
}

IV
next(self)
    kino_Lexicon *self;
CODE:
    RETVAL = Kino_Lex_Next(self);
OUTPUT: RETVAL

void
reset(self)
    kino_Lexicon *self;
PPCODE:
    Kino_Lex_Reset(self);

chy_i32_t
get_size(self);
    kino_Lexicon *self;
CODE:
    RETVAL = Kino_Lex_Get_Size(self);
OUTPUT: RETVAL

chy_i32_t
get_term_num(self);
    kino_Lexicon *self;
CODE:
    RETVAL = Kino_Lex_Get_Term_Num(self);
OUTPUT: RETVAL

SV*
get_term(self);
    kino_Lexicon *self;
CODE:
{
    kino_Term *term = Kino_Lex_Get_Term(self);
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
    kino_Lexicon *self;
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::Lexicon::build_sort_cache_args");
    kino_PostingList *plist = extract_obj(args_hash, SNL("posting_list"), 
        "KinoSearch::Index::PostingList");
    chy_u32_t max_doc = extract_uv(args_hash, SNL("max_doc"));

    RETVAL = Kino_Lex_Build_Sort_Cache(self, plist, max_doc);
}
OUTPUT: RETVAL

void
seek_by_num(self, term_num)
    kino_Lexicon *self;
    chy_i32_t term_num;
PPCODE:
    Kino_Lex_Seek_By_Num(self, term_num);

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::Lexicon - Scan through a list of Terms.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Conceptually, a Lexicon is a array of Term => TermInfo pairs, sorted
first by field number, then term sort order.  The implementations in
KinoSearch solve the same problem that tied arrays solve: it is possible to
iterate through the array while loading as little as possible into memory.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut



