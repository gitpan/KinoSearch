package KinoSearch::Index::DelDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::BitVector );

# instance vars:
my %num_deletions;

sub new {
    my $self = shift->SUPER::new;
    $num_deletions{"$self"} = 0;
    return $self;
}

# Read a deletions file if one exists.
sub read_deldocs {
    my ( $self, $invindex, $filename ) = @_;

    # load the file into memory if it's there
    if ( $invindex->file_exists($filename) ) {
        my $instream = $invindex->open_instream($filename);
        my $byte_size;
        ( $byte_size, $num_deletions{"$self"} ) = $instream->lu_read('ii');
        $self->set_bits( $instream->lu_read("a$byte_size") );
        $instream->close;
    }
}

# Blast out a hard copy of the deletions held in memory.
sub write_deldocs {
    my ( $self, $invindex, $filename, $max_doc ) = @_;
    my $outstream = $invindex->open_outstream($filename);

    # pad out obj->bits
    $self->set_capacity($max_doc);

    # write header followed by deletions data
    my $byte_size = $max_doc >> 3;
    $outstream->lu_write(
        "iia$byte_size",         $byte_size,
        $num_deletions{"$self"}, $self->get_bits,
    );

    $outstream->close;
}

# Mark a doc as deleted.
sub set {
    my ( $self, $doc_num ) = @_;
    # ... only if it isn't already deleted
    if ( !$self->get($doc_num) ) {
        $self->SUPER::set($doc_num);
        $num_deletions{"$self"}++;
    }
}

# Undelete a doc.
sub clear {
    my ( $self, $doc_num ) = @_;
    # ... only if it was deleted before
    if ( $self->get($doc_num) ) {
        $self->SUPER::clear($doc_num);
        $num_deletions{"$self"}--;
    }
}

sub get_num_deletions { $num_deletions{"$_[0]"} }

# If these get implemented, we'll need to write a range_count(first, last)
# method for BitVector.
sub bulk_set   { shift->todo_death }
sub bulk_clear { shift->todo_death }

sub DESTROY {
    my $self = shift;
    delete $num_deletions{"$self"};
    $self->SUPER::DESTROY;
}

1;

__END__

__XS__

MODULE = KinoSearch PACKAGE = KinoSearch::Index::DelDocs

=for comment

A doc_map is used when consolidating a segment.  It's a C array of U32
(stored in a scalar) where the offset from the start represents the original
doc_num, and the value represents the new doc_num.  _get_doc_map maps around
deleted docs, hence the name: if doc 2 is deleted, the map will be 0, 1, -1,
2, 3...

=cut

SV* 
get_doc_map(obj, max);
    BitVector *obj;
    I32        max;
PREINIT:
    I32       *doc_map, *doc_map_start, *doc_map_end;
    I32        new_doc_num;
    int        i;                   /* iterator */
CODE:
{
    RETVAL = newSV(max * sizeof(I32) + 1);
    SvCUR_set(RETVAL, max * sizeof(I32));
    SvPOK_on(RETVAL);
    doc_map = (I32*)SvPVX(RETVAL);

    new_doc_num = 0;
    for (i = 0; i < max; i++) {
        if (Kino_BitVec_get(obj, i))
            *doc_map++ = -1;
        else
            *doc_map++ = new_doc_num++;
    }
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::DelDocs - manage documents deleted from an invindex

=head1 DESCRIPTION

DelDocs provides the low-level mechanisms for declaring a document deleted
from a segment, and for finding out whether or not a particular document has
been deleted.

Note that documents are not actually gone from the invindex until the segment
gets rewritten.

=head1 TODO

Consider ways to synchronize instances of this class so that there will be
exactly one instance per segment.  That way, if an InvIndexer uses the instance
to delete a document, readers would have the modified vecstring available
right away without having to reread the .del file.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05.

=end devdocs
=cut
