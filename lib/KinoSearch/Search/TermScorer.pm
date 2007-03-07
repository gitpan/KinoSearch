use strict;
use warnings;

package KinoSearch::Search::TermScorer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Scorer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        weight    => undef,
        term_docs => undef,
    );
}
our %instance_vars;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    my $self = $class->_new( $args{similarity} );

    $self->_set_term_docs( $args{term_docs} );
    $self->_set_weight( $args{weight} );
    $self->_set_weight_value( $args{weight}->get_value );

    $self->_fill_score_cache;

    return $self;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::TermScorer

kino_TermScorer*
_new(class, sim)
    const classname_char *class;
    kino_Similarity *sim;
CODE:
    RETVAL = kino_TermScorer_new(sim);
    KINO_UNUSED_VAR(class);
OUTPUT: RETVAL

void
_fill_score_cache(self)
    kino_TermScorer* self;
PPCODE:
    kino_TermScorer_fill_score_cache(self);

void
_term_scorer_set_or_get(self, ...)
    kino_TermScorer *self;
ALIAS:
    _set_term_docs    = 1
    _get_term_docs    = 2
    _set_weight       = 3
    _get_weight       = 4
    _set_weight_value = 5
    _get_weight_value = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  REFCOUNT_DEC(self->term_docs);
             EXTRACT_STRUCT( ST(1), self->term_docs, kino_TermDocs*, 
                "KinoSearch::Index::TermDocs");
             REFCOUNT_INC(self->term_docs);
             break;

    case 2:  retval = kobj_to_pobj(self->term_docs);
             break;

    case 3:  if (self->weight_ref != NULL)
                SvREFCNT_dec((SV*)self->weight_ref); 
             if (!sv_derived_from( ST(1), "KinoSearch::Search::Weight"))
                CONFESS("not a KinoSearch::Search::Weight");
             self->weight_ref = (void*)newSVsv( ST(1) );
             break;

    case 4:  retval = self->weight_ref == NULL 
                ? newSV(0)
                : newSVsv((SV*)self->weight_ref);
             break;

    case 5:  self->weight_value = SvNV( ST(1) );
             break;

    case 6:  retval = newSVnv(self->weight_value);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::TermScorer - Scorer for TermQuery.

=head1 DESCRIPTION 

Subclass of Scorer which scores individual Terms.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

