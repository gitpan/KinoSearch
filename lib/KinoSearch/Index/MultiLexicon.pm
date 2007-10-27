use strict;
use warnings;

package KinoSearch::Index::MultiLexicon;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::Lexicon );

our %instance_vars = (
    # constructor params
    field       => undef,
    sub_readers => undef,
    lex_cache   => undef,
);

use KinoSearch::Index::Term;
use KinoSearch::Index::SegLexicon;
use KinoSearch::Util::VArray;

sub new {
    my $self = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );
    for (qw( field sub_readers )) {
        confess("Missing required arg '$_'") unless defined $args{$_};
    }
    my ( $field, $sub_readers ) = @args{qw( field sub_readers )};

    my $seg_lexicons
        = KinoSearch::Util::VArray->new( capacity => scalar @$sub_readers );
    for my $seg_reader (@$sub_readers) {
        my $seg_lexicon = $seg_reader->look_up_field($field);
        next unless defined $seg_lexicon;
        $seg_lexicons->push($seg_lexicon);
    }

    # no lexicon if the field isn't indexed or has no terms
    return unless $seg_lexicons->get_size;

    return _new( $args{field}, $seg_lexicons, $args{lex_cache} );
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::MultiLexicon 

kino_MultiLexicon*
_new(field, seg_lexicons, lex_cache_sv)
    kino_ByteBuf field;
    kino_VArray *seg_lexicons;
    SV *lex_cache_sv;
CODE:
{
    kino_LexCache *lex_cache = NULL;
    MAYBE_EXTRACT_STRUCT(lex_cache_sv, lex_cache, kino_LexCache*,
        "KinoSearch::Index::LexCache");
    RETVAL = kino_MultiLex_new(&field, seg_lexicons, lex_cache);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_MultiLexicon *self;
ALIAS:
    get_lex_cache             = 2  
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = self->lex_cache == NULL
                ? newSV(0)
                : kobj_to_pobj(self->lex_cache); 
             break;
    END_SET_OR_GET_SWITCH
}


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::MultiLexicon - Multi-segment Lexicon.

=head1 DESCRIPTION

Multi-segment implementation of KinoSearch::Index::Lexicon, aggregating the
output of multiple SegLexicons.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


