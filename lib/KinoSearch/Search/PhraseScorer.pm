use strict;
use warnings;

package KinoSearch::Search::PhraseScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        weight         => undef,
        term_docs      => [],
        phrase_offsets => [],
        slop           => 0,
    );
}
our %instance_vars;

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    # set/derive some member vars
    confess("Sloppy phrase matching not yet implemented")
        unless $args{slop} == 0;    # TODO -- enable slop.

    # sort terms by ascending frequency
    confess("positions count doesn't match term count")
        unless $#{ $args{term_docs} } == $#{ $args{phrase_offsets} };
    my @by_size = sort { $a->[0]->get_doc_freq <=> $b->[0]->get_doc_freq }
        map { [ $args{term_docs}[$_], $args{phrase_offsets}[$_] ] }
        0 .. $#{ $args{term_docs} };
    my @term_docs      = map { $_->[0] } @by_size;
    my @phrase_offsets = map { $_->[1] } @by_size;

    my $self = $class->_new(
        \@term_docs, \@phrase_offsets,
        $args{weight}->get_value,
        @args{qw( similarity slop )}
    );

    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::PhraseScorer

kino_PhraseScorer*
_new(class, term_docs_av, offsets_av, weight_val, sim, slop)
    const classname_char *class;
    AV *term_docs_av;
    AV *offsets_av;
    float weight_val;
    kino_Similarity *sim;
    kino_u32_t slop;
CODE:
{
    kino_u32_t num_elements = av_len(term_docs_av) + 1;
    kino_TermDocs **const term_docs 
        = KINO_MALLOCATE(num_elements, kino_TermDocs*);
    kino_u32_t *const phrase_offsets
        = KINO_MALLOCATE(num_elements, kino_u32_t);
    kino_u32_t i;

    /* create an array of TermDocs* */
    for(i = 0; i < num_elements; i++) {
        SV **const term_docs_sv_ptr  = av_fetch(term_docs_av, i, 0);
        SV **const offset_sv_ptr = av_fetch(offsets_av, i, 0);
        const IV tmp = SvIV((SV*)SvRV( *term_docs_sv_ptr ));
        kino_TermDocs *const td = INT2PTR(kino_TermDocs*, tmp);
        term_docs[i] = td;
        phrase_offsets[i] = SvIV( *offset_sv_ptr );
    }
    RETVAL = kino_PhraseScorer_new(num_elements, term_docs, phrase_offsets, 
        weight_val, sim, slop);
    KINO_UNUSED_VAR(class);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::PhraseScorer - Scorer for PhraseQuery.

=head1 DESCRIPTION 

Score phrases.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
