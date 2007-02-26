use strict;
use warnings;

package KinoSearch::Index::TermDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN { __PACKAGE__->init_instance_vars(); }

sub close { shift->abstract_death }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermDocs

void
seek(self, term_sv)
    kino_TermDocs *self;
    SV *term_sv;
PPCODE:
{
    kino_Term *target = NULL;
    /* if maybe_tinfo_sv is undef, tinfo is NULL */
    if (SvOK(term_sv)) {
        EXTRACT_STRUCT(term_sv, target, kino_Term*, 
            "KinoSearch::Index::Term");
    }
    Kino_TermDocs_Seek(self, target);
}


bool
next(self)
    kino_TermDocs *self;
CODE:
    RETVAL = Kino_TermDocs_Next(self);
OUTPUT: RETVAL

kino_u32_t
bulk_read(self, doc_nums_sv, field_boosts_sv, freqs_sv, prox_sv, boosts_sv, num_wanted)
    kino_TermDocs   *self
    SV         *doc_nums_sv;
    SV         *field_boosts_sv;
    SV         *freqs_sv;
    SV         *prox_sv;
    SV         *boosts_sv;
    kino_u32_t  num_wanted;
CODE:
{
    kino_ByteBuf *doc_nums_bb     = kino_BB_new(0);
    kino_ByteBuf *field_boosts_bb = kino_BB_new(0);
    kino_ByteBuf *freqs_bb        = kino_BB_new(0);
    kino_ByteBuf *prox_bb         = kino_BB_new(0);
    kino_ByteBuf *boosts_bb       = kino_BB_new(0);
    RETVAL = Kino_TermDocs_Bulk_Read(self, doc_nums_bb, field_boosts_bb, 
        freqs_bb, prox_bb, boosts_bb, num_wanted);
    sv_setpvn(doc_nums_sv, doc_nums_bb->ptr, doc_nums_bb->len);
    sv_setpvn(field_boosts_sv, field_boosts_bb->ptr, field_boosts_bb->len);
    sv_setpvn(freqs_sv, freqs_bb->ptr, freqs_bb->len);
    sv_setpvn(boosts_sv, boosts_bb->ptr, boosts_bb->len);
    sv_setpvn(prox_sv, prox_bb->ptr, prox_bb->len);
    REFCOUNT_DEC(doc_nums_bb);
    REFCOUNT_DEC(field_boosts_bb);
    REFCOUNT_DEC(freqs_bb);
    REFCOUNT_DEC(prox_bb);
    REFCOUNT_DEC(boosts_bb);
}
OUTPUT: RETVAL

bool
skip_to(self, target)
    kino_TermDocs *self;
    kino_u32_t target;
CODE:
    RETVAL = Kino_TermDocs_Skip_To(self, target);
OUTPUT: RETVAL

void
_parent_set_or_get(self, ...)
    kino_TermDocs *self;
ALIAS:
    get_doc       = 2
    get_freq      = 4
    get_positions = 6
    set_doc_freq  = 7
    get_doc_freq  = 8
PREINIT:
    kino_u32_t num;
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  num = Kino_TermDocs_Get_Doc(self);
             retval = num == KINO_TERM_DOCS_SENTINEL 
                 ? &PL_sv_undef
                 : newSVuv(num);
             break;

    case 4:  num = Kino_TermDocs_Get_Freq(self);
             retval = num == KINO_TERM_DOCS_SENTINEL 
                 ? &PL_sv_undef 
                 : newSVuv(num);
             break;

    case 6:  retval = bb_to_sv(Kino_TermDocs_Get_Positions(self));
             break;

    case 7:  Kino_TermDocs_Set_Doc_Freq(self, (kino_u32_t)SvUV(ST(1)) );
             break;

    case 8:  num = Kino_TermDocs_Get_Doc_Freq(self);
             retval = num == KINO_TERM_DOCS_SENTINEL 
                 ? &PL_sv_undef
                 : newSVuv(num);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Index::TermDocs - Retrieve list of docs which contain a Term.

=head1 SYNOPSIS

    # abstract base class, but here's how a subclass works:

    $term_docs->seek($term);
    my $num_got  = $term_docs->bulk_read( $docs, $freqs, $boosts, 
        $num_to_read );
    my @doc_nums = unpack( 'I*', $docs );
    my @tf_ds    = unpack( 'I*', $freqs );    # term frequency in document
    my @boosts   = unpack( 'C*', $boosts );   # 1 boost for each position

    # alternately...
    $term_docs->set_read_positions(1);
    while ($term_docs->next) {
        do_something_with(
            doc       => $term_docs->get_doc,
            freq      => $term_docs->get_freq,
            positions => $term_docs->get_positions,
            boosts    => $term_docs->get_boosts;
        );
    }

=head1 DESCRIPTION

Feed a TermDocs object a Term to get docs, freqs, and boosts.  If a term is
present in the portion of an index that a TermDocs subclass is responsible
for, the object is used to access the doc_nums for the documents in which it
appears, plus the number of appearances, plus (optionally), the positions
at which the term appears in the document.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut

