package KinoSearch::Index::TermDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars();

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return $class->_construct_parent;
}

=begin comment

    $termdocs->seek($term);

Locate the TermDocs object at a particular term.

=end comment
=cut

sub seek { shift->abstract_death }

sub close { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermDocs

void
_construct_parent(class)
    char *class;
PREINIT:
    TermDocs *obj;
PPCODE:
    obj   = Kino_TermDocs_construct_parent();
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), class, (void*)obj);
    XSRETURN(1);

=begin comment

    while ($term_docs->next) {
        # ...
    }

Advance the TermDocs object to the next document.  Returns false when the
iterator is exhausted, true otherwise.

=end comment
=cut

bool
next(obj)
    TermDocs *obj;
CODE:
    RETVAL = obj->next(obj);
OUTPUT: RETVAL

=begin comment

To do.

=end comment
=cut

bool
skip_to(obj, target)
    TermDocs *obj;
    U32       target;
CODE:
    RETVAL = obj->skip_to(obj, target);
OUTPUT: RETVAL

SV*
_parent_set_or_get(obj, ...)
    TermDocs *obj;
ALIAS:
    set_doc       = 1
    get_doc       = 2
    set_freq      = 3
    get_freq      = 4
    set_doc_freq  = 5
    get_doc_freq  = 6
    set_positions = 7
    get_positions = 8
CODE:
{
    /* if called as a setter, make sure the extra arg is there */
    if (ix % 2 == 1 && items != 2)
        Kino_confess("usage: $term_docs->set_xxxxxx($val)");

    switch (ix) {

    case 1:  obj->doc = SvIV(ST(1));
             /* fall through */
    case 2:  RETVAL = obj->doc == KINO_TERM_DOCS_SENTINEL 
             ? newSV(0) 
             : newSVuv(obj->doc);
             break;

    case 3:  obj->freq = SvIV(ST(1));
             /* fall through */
    case 4:  RETVAL = obj->freq == KINO_TERM_DOCS_SENTINEL 
             ? newSV(0) 
             : newSVuv(obj->freq);
             break;

    case 5:  obj->doc_freq = SvIV(ST(1));
             /* fall through */
    case 6:  RETVAL = obj->doc_freq == KINO_TERM_DOCS_SENTINEL 
             ? newSV(0) 
             : newSVuv(obj->doc_freq);
             break;

    case 7:  SvREFCNT_dec(obj->positions);
             obj->positions = newSVsv(ST(1));
             /* fall through */
    case 8:  RETVAL = newSVsv(obj->positions);
             break;
    }
}
    OUTPUT: RETVAL

void
DESTROY(obj)
    TermDocs *obj;
PPCODE:
    Kino_TermDocs_destroy(obj);


__H__

#ifndef H_KINO_TERM_DOCS
#define H_KINO_TERM_DOCS 1

#define KINO_TERM_DOCS_SENTINEL 0xFFFFFFFF

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilMemManager.h"

typedef struct termdocs {
    void  *child;
    U32    doc;
    U32    freq;
    U32    doc_freq;
    SV    *positions;
    bool (*next)(struct termdocs*);
    bool (*skip_to)(struct termdocs*, U32);
    U32  (*read)(struct termdocs*, SV*, SV*, U32);
} TermDocs;

TermDocs* Kino_TermDocs_construct_parent();
bool Kino_TermDocs_next_death(TermDocs*);
bool Kino_TermDocs_skip_to_death(TermDocs*, U32);
U32  Kino_TermDocs_read_death(TermDocs*, SV*, SV*, U32);
void Kino_TermDocs_destroy(TermDocs*);

#endif /* include guard */

__C__

#include "KinoSearchIndexTermDocs.h"

TermDocs*
Kino_TermDocs_construct_parent() {
    TermDocs* term_docs;
    
    Kino_New(0, term_docs, 1, TermDocs);
    term_docs->doc  = KINO_TERM_DOCS_SENTINEL;
    term_docs->freq = KINO_TERM_DOCS_SENTINEL;

    /* force the subclass to override functions */
    term_docs->next    = Kino_TermDocs_next_death;
    term_docs->skip_to = Kino_TermDocs_skip_to_death;

    /* term_docs->positions starts life as an empty string */
    term_docs->positions = newSV(1);
    SvCUR_set(term_docs->positions, 0);
    SvPOK_on(term_docs->positions);

    return term_docs;
}

bool
Kino_TermDocs_next_death(TermDocs *term_docs) {
    Kino_confess("term_docs->next must be defined in a subclass");
}

U32  
Kino_TermDocs_read_death(TermDocs* term_docs, SV* doc_nums_sv, SV* freqs_sv,
                         U32 num_wanted) {
    Kino_confess("term_docs->read must be defined in a subclass");
}

bool
Kino_TermDocs_skip_to_death(TermDocs *term_docs, U32 target) {
    Kino_confess("term_docs->skip_to must be defined in a subclass");
}

void
Kino_TermDocs_destroy(TermDocs *term_docs) {
    SvREFCNT_dec(term_docs->positions);
    Kino_Safefree(term_docs);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::TermDocs - retrieve list of docs which contain a Term

=head1 SYNOPSIS

    # abstract base class, but here's how a subclass works:

    $term_docs->seek($term);
    my $num_got  = $term_docs->read( $docs, $freqs, $num_to_read );
    my @doc_nums = unpack( 'I*', $docs );
    my @tf_ds    = unpack( 'I*', $freqs );    # term frequency in document

    # alternately...
    $term_docs->set_read_positions(1);
    while ($term_docs->next) {
        do_something_with(
            doc       => $term_docs->get_doc,
            freq      => $term_docs->get_freq,
            positions => $term_docs->get_positions,
        );
    }

=head1 DESCRIPTION

Feed a TermDocs object a Term to get docs (and freqs).  If a term is present
in the portion of an index that a TermDocs subclass is responsible for, the
object is used to access the doc_nums for the documents in which it appears,
plus the number of appearances, plus (optionally), the positions at which the
term appears in the document.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut

