use strict;
use warnings;

package KinoSearch::Index::MultiTermDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermDocs );

BEGIN {
    __PACKAGE__->init_instance_vars(
        sub_readers => [],
        starts      => [],
    );
}
our %instance_vars;

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args = ( %instance_vars, @_ );

    # get a SegTermDocs for each segment
    my @sub_term_docs = map { $_->term_docs } @{ $args{sub_readers} };
    my $self = $class->_new( \@sub_term_docs, $args{starts} );

    return $self;
}

sub close {
    my $self = shift;
    $_->close for @{ $self->_get_sub_term_docs };
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::MultiTermDocs

kino_MultiTermDocs*
_new(class, sub_term_docs_av, starts_av)
    const classname_char *class;
    AV *sub_term_docs_av;
    AV *starts_av;
CODE:
{
    kino_u32_t num_subs = av_len(starts_av) + 1;
    kino_TermDocs **sub_term_docs = KINO_MALLOCATE(num_subs, kino_TermDocs*);
    kino_u32_t *starts = KINO_MALLOCATE(num_subs, kino_u32_t);
    kino_u32_t i;

    /* extract starts from starts array, sub-TermDocs from the subs array */
    for (i = 0; i < num_subs; i++) {
        kino_TermDocs *seg_term_docs;
        IV temp_iv;
        SV **const std_sv_ptr = av_fetch(sub_term_docs_av, i, 0);
        SV **const start_sv_ptr = av_fetch(starts_av, i, 0);

        /* error checking */
        if (std_sv_ptr == NULL)
            CONFESS("Unexpected NULL");
        if (start_sv_ptr == NULL)
            CONFESS("Unexpected NULL");
        if (!sv_derived_from(*std_sv_ptr, "KinoSearch::Index::TermDocs"))
            CONFESS("Not a TermDocs");

        temp_iv = SvIV(SvRV(*std_sv_ptr));
        seg_term_docs = INT2PTR(kino_TermDocs*, temp_iv);
        sub_term_docs[i] = seg_term_docs;

        starts[i] = SvUV(*start_sv_ptr);
    }
    RETVAL = kino_MultiTermDocs_new(num_subs, sub_term_docs, starts);
    KINO_UNUSED_VAR(class);
}
OUTPUT: RETVAL


=for comment
Helper for seek().

=cut

void
_set_or_get(self, ...)
    kino_MultiTermDocs *self;
ALIAS:
    _get_sub_term_docs = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH
        
    case 2:  {
                AV *out_av = newAV();
                kino_u32_t i;
                kino_TermDocs **sub_term_docs = self->sub_term_docs;
                for (i = 0; i < self->num_subs; i++) {
                    SV *std_sv = kobj_to_pobj(sub_term_docs[i]);
                    av_push(out_av, std_sv);
                }
                retval = newRV_noinc((SV*)out_av);
             }
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::MultiTermDocs - Multi-segment TermDocs.

=head1 DESCRIPTION 

Multi-segment implementation of KinoSearch::Index::TermDocs.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
