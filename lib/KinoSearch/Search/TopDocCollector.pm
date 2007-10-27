use strict;
use warnings;

package KinoSearch::Search::TopDocCollector;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::HitCollector );

our %instance_vars = (
    # constructor args
    size => undef,
);

use KinoSearch::Search::HitQueue;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::TopDocCollector

kino_TopDocCollector*
new(class, ...)
    const classname_char *class;
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::TopDocCollector::instance_vars");
    chy_u32_t num_hits = extract_uv(args_hash, SNL("size"));

    /* create object */
    CHY_UNUSED_VAR(class);
    RETVAL = kino_TDColl_new(num_hits);
}
OUTPUT: RETVAL


void
_set_or_get(self, ...)
    kino_TopDocCollector *self;
ALIAS:
    get_hit_queue    = 2
    get_total_hits   = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH
    
    case 2:  retval = kobj_to_pobj(self->hit_q);
             break;

    case 4:  retval = newSVuv(self->total_hits);
             break;
             
    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::TopDocCollector - Collect top-scoring documents.

=head1 DESCRIPTION

A TopDocCollector keeps the highest scoring N documents and their associated
scores in a HitQueue while iterating through a large list.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


