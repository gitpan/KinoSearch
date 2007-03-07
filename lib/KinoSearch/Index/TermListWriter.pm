use strict;
use warnings;

package KinoSearch::Index::TermListWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        invindex       => undef,
        seg_info       => undef,
        is_index       => 0,
        index_interval => 128,
        skip_interval  => 16,
    );
}
our %instance_vars;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermListWriter

kino_TermListWriter*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::TermListWriter::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    kino_i32_t  index_interval = extract_iv(args_hash, SNL("index_interval"));
    kino_i32_t  skip_interval  = extract_iv(args_hash, SNL("skip_interval"));
    kino_bool_t is_index       = extract_iv(args_hash, SNL("is_index"));

    if (is_index) 
        CONFESS("Cant create index TermListWriter from Perl");

    RETVAL = kino_TLWriter_new(invindex, seg_info, is_index,
        index_interval, skip_interval);
}
OUTPUT: RETVAL

void
finish(self)
    kino_TermListWriter *self;
PPCODE:
    Kino_TLWriter_Finish(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermListWriter - Write a term dictionary.

=head1 DESCRIPTION

The TermListWriter writes both parts of the term dictionary.  The primary
instance creates a shadow TermListWriter that writes the index.

=head TODO

Find the optimum TermIndexInterval.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

