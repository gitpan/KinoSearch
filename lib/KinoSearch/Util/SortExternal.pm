use strict;
use warnings;

package KinoSearch::Util::SortExternal;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        invindex      => undef,
        seg_info      => undef,
        mem_threshold => _DEFAULT_MEM_THRESHOLD,
    );
}

# Prepare to start fetching sorted results.
sub sort_all {
    my $self     = shift;
    my $seg_info = $self->_get_seg_info;
    my $folder   = $self->_get_invindex->get_folder;

    # deal with any items in the cache right now
    if ( $self->_get_num_runs == 0 ) {
        # if we've never exceeded mem_threshold, sort in-memory
        $self->_sort_cache;
    }
    else {
        # create a run from whatever's in the cache right now
        $self->_sort_run;
    }

    # done adding elements, so close file and reopen as an instream
    $self->_get_outstream->sclose;
    my $filename = $seg_info->get_seg_name . ".srt";
    my $instream = $folder->open_instream($filename);
    $self->_set_instream($instream);
}

sub close { shift->_get_instream()->sclose }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::SortExternal

kino_SortExternal*
new(class, ...)
    const classname_char *class;
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Util::SortExternal::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    kino_u32_t mem_threshold = extract_uv(args_hash, SNL("mem_threshold"));

    /* build object */
    KINO_UNUSED_VAR(class);
    RETVAL = kino_SortEx_new(invindex, seg_info, mem_threshold);
}
OUTPUT: RETVAL

=for comment

Add one or more items to the sort pool.

=cut

void
feed(self, ...)
    kino_SortExternal *self;
PPCODE:
{
    I32 i;
    for (i = 1; i < items; i++) {   
        SV const * item_sv = ST(i);
        if (!SvPOK(item_sv))
            continue;
        Kino_SortEx_Feed(self, SvPVX(item_sv), SvCUR(item_sv));
    }
}

SV*
fetch(self)
    kino_SortExternal *self;
CODE:
{
    kino_ByteBuf *bb = Kino_SortEx_Fetch(self);
    RETVAL = newSV(0);
    if (bb == NULL) {
    }
    else {
        sv_setpvn(RETVAL, bb->ptr, bb->len);
        REFCOUNT_DEC(bb);
    }
}
OUTPUT: RETVAL


void
_sort_cache(self)
    kino_SortExternal *self;
PPCODE:
    Kino_SortEx_Sort_Cache(self);

void
_sort_run(self);
    kino_SortExternal *self;
PPCODE:
    Kino_SortEx_Sort_Run(self);


void
_set_or_get(self, ...)
    kino_SortExternal *self;
ALIAS:
    _get_outstream = 2
    _set_instream  = 3
    _get_instream  = 4
    _get_num_runs  = 6
    _get_invindex  = 8
    _get_seg_info  = 10
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->outstream);
             break;
             
    case 3:  if (self->instream != NULL)
                REFCOUNT_DEC(self->instream);
             EXTRACT_STRUCT( ST(1), self->instream, kino_InStream*, 
                "KinoSearch::Store::InStream");
             REFCOUNT_INC(self->instream);
             break;

    case 4:  retval = self->instream == NULL
                ? newSV(0)
                : kobj_to_pobj(self->instream);
             break;

    case 6:  retval = newSViv(self->num_runs);
             break;

    case 8:  retval = kobj_to_pobj(self->invindex);
             break;
             
    case 10: retval = kobj_to_pobj(self->seg_info);
             break;

    END_SET_OR_GET_SWITCH
}

IV
_DEFAULT_MEM_THRESHOLD()
CODE:
    RETVAL = KINO_SORTEX_DEFAULT_MEM_THRESHOLD;
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

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
