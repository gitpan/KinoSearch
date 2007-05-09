use strict;
use warnings;

package KinoSearch::Index::LexWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = (
    # constructor params
    invindex => undef,
    seg_info => undef,
    is_index => 0,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::LexWriter

kino_LexWriter*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::LexWriter::instance_vars");
    kino_InvIndex *invindex = (kino_InvIndex*)extract_obj(
        args_hash, SNL("invindex"), "KinoSearch::InvIndex");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    chy_bool_t is_index       = extract_iv(args_hash, SNL("is_index"));

    if (is_index) 
        CONFESS("Cant create index LexWriter from Perl");

    RETVAL = kino_LexWriter_new(invindex, seg_info, is_index);
}
OUTPUT: RETVAL

void
finish(self)
    kino_LexWriter *self;
PPCODE:
    Kino_LexWriter_Finish(self);

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::LexWriter - Write a term dictionary.

=head1 DESCRIPTION

The LexWriter writes both parts of the term dictionary.  The primary
instance creates a shadow LexWriter that writes the index.

=head TODO

Find the optimum TermIndexInterval.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
