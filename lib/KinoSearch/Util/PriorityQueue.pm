use strict;
use warnings;

package KinoSearch::Util::PriorityQueue;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        max_size => undef,
    );
}
our %instance_vars;

1;

__END__

__XS__

MODULE =  KinoSearch    PACKAGE = KinoSearch::Util::PriorityQueue

kino_PriorityQueue*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::PriorityQueue::instance_vars");
    kino_u32_t max_size = extract_uv(args_hash, SNL("max_size"));

    /* build object */
    RETVAL = kino_PriQ_new(max_size, less_than_sviv, kino_sv_free);
}
OUTPUT: RETVAL

kino_bool_t
insert(self, element)
    kino_PriorityQueue *self;
    SV                 *element;
CODE:
    RETVAL = Kino_PriQ_Insert(self, newSVsv(element));
OUTPUT: RETVAL

SV*
pop(self)
    kino_PriorityQueue *self;
CODE:
    RETVAL = (SV*)Kino_PriQ_Pop(self);
    if (RETVAL == NULL) {
        RETVAL = &PL_sv_undef;
    }
    else {
        RETVAL = newSVsv(RETVAL);
    }
OUTPUT: RETVAL


SV*
peek(self)
    kino_PriorityQueue *self;
CODE:
    RETVAL = (SV*)Kino_PriQ_Peek(self);
    if (RETVAL == NULL) {
        RETVAL = &PL_sv_undef;
    }
    else {
        RETVAL = newSVsv(RETVAL);
    }
OUTPUT: RETVAL


void
pop_all(self)
    kino_PriorityQueue *self;
PPCODE:
{
    AV* out_av = newAV();
    
    if (self->size > 0) {
        kino_i32_t i;

        /* map the queue nodes onto the array in reverse order */
        av_extend(out_av, self->size - 1);
        for (i = self->size - 1; i >= 0; i--) {
            SV *const element_sv = newSVsv( Kino_PriQ_Pop(self) );
            av_store(out_av, i, element_sv);
        }
    }
    XPUSHs( sv_2mortal(newRV_noinc( (SV*)out_av )) );
    XSRETURN(1);
}



void
_set_or_get(self, ...)
    kino_PriorityQueue *self;
ALIAS:
    get_size      = 2
    get_max_size  = 4
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVuv(self->size);
             break;

    case 4:  retval = newSVuv(self->max_size);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::PriorityQueue - Classic heap sort / priority queue.

=head1 DESCRIPTION

PriorityQueue implements a textbook heap-sort/priority-queue algorithm.  This
particular variant leaves slot 0 in the queue open in order to keep the
relationship between node rank and index clear in the up_heap and down_heap
routines.

The nodes in this implementation are all perl scalars, which allows us to use
Perl's reference counting to manage memory.  However, the underlying queue
management methods are all written in C, which allows them to be used within
other C routines without expensive callbacks to Perl. 

Subclass constructors must redefine the C pointer-to-function, less_than. The
default behavior is to compare the SvIV value of two scalars.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

