use strict;
use warnings;

package KinoSearch::Index::DelDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::BitVector );

use KinoSearch::Util::IntMap;

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args
        invindex => undef,
        seg_info => undef,
    );
}
our %instance_vars;

sub close { }

1;

__END__

__XS__

MODULE = KinoSearch PACKAGE = KinoSearch::Index::DelDocs

kino_DelDocs*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::DelDocs::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");

    /* build object */
    RETVAL = kino_DelDocs_new(invindex, seg_info);
}
OUTPUT: RETVAL

void
read_deldocs(self)
    kino_DelDocs *self; 
PPCODE:
    Kino_DelDocs_Read_Deldocs(self);

void
write_deldocs(self)
    kino_DelDocs *self; 
PPCODE:
    Kino_DelDocs_Write_Deldocs(self);

kino_i32_t
get_num_deletions(self)
    kino_DelDocs *self;
CODE:
    RETVAL = Kino_BitVec_Count(self);
OUTPUT: RETVAL

kino_IntMap*
generate_doc_map(self, offset);
    kino_DelDocs  *self;
    kino_i32_t     offset;
CODE:
    RETVAL = Kino_DelDocs_Generate_Doc_Map(self, offset);
OUTPUT: RETVAL

void
delete_by_term_docs(self, term_docs)
    kino_DelDocs *self;
    kino_TermDocs *term_docs;
PPCODE:
    Kino_DelDocs_Delete_By_Term_Docs(self, term_docs);


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::DelDocs - Manage documents deleted from an InvIndex.

=head1 DESCRIPTION

DelDocs provides the low-level mechanisms for declaring a document deleted
from a segment, and for finding out whether or not a particular document has
been deleted.

Note that documents are not actually gone from the InvIndex until the segment
gets rewritten.

=head1 TODO

Consider ways to synchronize instances of this class so that there will be
exactly one instance per segment.  That way, if an InvIndexer uses the instance
to delete a document, readers would have the modified vecstring available
right away without having to reread the .del file.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
