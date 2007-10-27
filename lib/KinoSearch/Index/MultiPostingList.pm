use strict;
use warnings;

package KinoSearch::Index::MultiPostingList;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::PostingList );
use KinoSearch::Util::VArray;

our %instance_vars = (
    # params
    sub_readers => undef,
    starts      => undef,
    field       => undef,
);

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    # get a SegPostingList for each segment
    my $sub_plists = KinoSearch::Util::VArray->new(
        capacity => $args{starts}->get_size );
    for my $sub_reader ( @{ $args{sub_readers} } ) {
        my $sub_plist = $sub_reader->posting_list( field => $args{field} );
        $sub_plists->push($sub_plist);
    }
    my $self = $class->_new( $args{field}, $sub_plists, $args{starts} );

    return $self;
}

sub close {
    my $self = shift;
    $_->close for @{ $self->_get_sub_plists };
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::MultiPostingList

kino_MultiPostingList*
_new(class, field, sub_plists, starts)
    const classname_char *class;
    kino_ByteBuf field;
    kino_VArray *sub_plists;
    kino_VArray *starts;
CODE:
    RETVAL = kino_MultiPList_new(&field, sub_plists, starts);
    CHY_UNUSED_VAR(class);
OUTPUT: RETVAL

=for comment
Helper for seek().

=cut

void
_set_or_get(self, ...)
    kino_MultiPostingList *self;
ALIAS:
    _get_sub_plists = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH
        
    case 2:  {
                AV          *const out_av     = newAV();
                kino_VArray *const sub_plists = self->sub_plists;
                chy_u32_t i;
                for (i = 0; i < self->num_subs; i++) {
                    kino_SegPostingList *sub_plist
                        = (kino_SegPostingList*)Kino_VA_Fetch(sub_plists, i);
                    SV *sub_plist_sv = kobj_to_pobj(sub_plist);
                    av_push(out_av, sub_plist_sv);
                }
                retval = newRV_noinc((SV*)out_av);
             }
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::MultiPostingList - Multi-segment PostingList.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
