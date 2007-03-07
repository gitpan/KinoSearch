use strict;
use warnings;

package KinoSearch::Index::SegTermDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Index::TermDocs );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params
        seg_reader => undef,

        # additional constructor params for C
        schema        => undef,
        folder        => undef,
        seg_info      => undef,
        deldocs       => undef,
        skip_interval => undef,
        tl_reader     => undef,
    );
}
our %instance_vars;

sub new {
    my $class = shift;
    confess kerror() unless verify_args( \%instance_vars, @_ );
    my %args       = ( %instance_vars, @_ );
    my $seg_reader = $args{seg_reader};

    my $self = $class->_new(
        tl_reader     => $seg_reader->get_tl_reader,
        schema        => $seg_reader->get_schema,
        seg_info      => $seg_reader->get_seg_info,
        folder        => $seg_reader->get_comp_file_reader,
        deldocs       => $seg_reader->get_deldocs,
        skip_interval => $seg_reader->get_skip_interval,
    );

    return $self;
}

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::SegTermDocs

kino_SegTermDocs*
_new(...)
CODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::SegTermDocs::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = (kino_SegInfo*)extract_obj(
        args_hash, SNL("seg_info"), "KinoSearch::Index::SegInfo");
    kino_DelDocs *deldocs = (kino_DelDocs*)extract_obj(
        args_hash, SNL("deldocs"), "KinoSearch::Index::DelDocs");
    kino_TermListReader *tl_reader = (kino_TermListReader*)extract_obj(
        args_hash, SNL("tl_reader"), "KinoSearch::Index::TermListReader");
    kino_u32_t skip_interval = extract_iv(args_hash, SNL("skip_interval"));

    RETVAL = kino_SegTermDocs_new(schema, folder, seg_info, tl_reader,
        deldocs, skip_interval);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::SegTermDocs - Single-segment TermDocs.

=head1 DESCRIPTION

Single-segment implemetation of KinoSearch::Index::TermDocs.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
