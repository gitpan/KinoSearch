use strict;
use warnings;

package KinoSearch::Util::SortExternal;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

package KinoSearch::Util::BBSortEx;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::SortExternal );

our %instance_vars = (
    # params
    invindex   => undef,
    seg_info   => undef,
    mem_thresh => KinoSearch::Util::SortExternal::_DEFAULT_MEM_THRESHOLD,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::SortExternal


void
flip(self)
    kino_SortExternal *self;
PPCODE:
    Kino_SortEx_Flip(self);

IV
_DEFAULT_MEM_THRESHOLD()
CODE:
    RETVAL = KINO_SORTEX_DEFAULT_MEM_THRESHOLD;
OUTPUT: RETVAL


MODULE = KinoSearch    PACKAGE = KinoSearch::Util::BBSortEx

kino_BBSortEx*
new(class, ...)
    const classname_char *class;
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::BBSortEx::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    chy_u32_t mem_thresh = extract_uv(args_hash, SNL("mem_thresh"));

    /* build object */
    CHY_UNUSED_VAR(class);
    RETVAL = kino_BBSortEx_new(invindex, seg_info, mem_thresh);
}
OUTPUT: RETVAL

=for comment

Add one or more items to the sort pool.

=cut

void
feed_str(self, ...)
    kino_SortExternal *self;
PPCODE:
{
    I32 i;
    for (i = 1; i < items; i++) {   
        SV const * item_sv = ST(i);
        if (!SvPOK(item_sv))
            continue;
        Kino_BBSortEx_Feed_Str(self, SvPVX(item_sv), SvCUR(item_sv));
    }
}

SV*
fetch(self)
    kino_SortExternal *self;
CODE:
{
    kino_ByteBuf *bb = (kino_ByteBuf*)Kino_SortEx_Fetch(self);
    RETVAL = newSV(0);
    if (bb == NULL) {
    }
    else {
        sv_setpvn(RETVAL, bb->ptr, bb->len);
        REFCOUNT_DEC(bb);
    }
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::SortExternal - External sorting.

=head1 DESCRIPTION

External sorting implementation, using lexical comparison.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
