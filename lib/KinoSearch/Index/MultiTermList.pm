use strict;
use warnings;

package KinoSearch::Index::MultiTermList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermList );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        field       => undef,
        sub_readers => undef,
        tl_cache    => undef,
    );
}
our %instance_vars;

use KinoSearch::Index::Term;
use KinoSearch::Index::SegTermList;
use KinoSearch::Util::VArray;

sub new {
    my $self = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );
    for (qw( field sub_readers )) {
        confess("Missing required arg '$_'") unless defined $args{$_};
    }
    my ( $field, $sub_readers ) = @args{qw( field sub_readers )};

    my $seg_term_lists
        = KinoSearch::Util::VArray->new( capacity => scalar @$sub_readers );
    for my $seg_reader (@$sub_readers) {
        my $seg_term_list = $seg_reader->start_field_terms($field);
        next unless defined $seg_term_list;
        $seg_term_lists->push($seg_term_list);
    }

    # no term list if the field isn't indexed or has no terms
    return unless $seg_term_lists->get_size;

    return _new( $args{field}, $seg_term_lists, $args{tl_cache} );
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::MultiTermList 

kino_MultiTermList*
_new(field, seg_term_lists, tl_cache_sv)
    kino_ByteBuf field;
    kino_VArray *seg_term_lists;
    SV *tl_cache_sv;
CODE:
{
    kino_TermListCache *tl_cache = NULL;
    if (SvOK(tl_cache_sv)) {
        EXTRACT_STRUCT(tl_cache_sv, tl_cache, kino_TermListCache*,
            "KinoSearch::Index::TermListCache");
    }
    RETVAL = kino_MultiTermList_new(&field, seg_term_lists, tl_cache);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_MultiTermList *self;
ALIAS:
    get_tl_cache             = 2  
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = self->tl_cache == NULL
                ? newSV(0)
                : kobj_to_pobj(self->tl_cache); 
             break;
    END_SET_OR_GET_SWITCH
}


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::MultiTermList - Multi-segment TermList.

=head1 DESCRIPTION

Multi-segment implementation of KinoSearch::Index::TermList, aggregating the
output of multiple SegTermLists.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


