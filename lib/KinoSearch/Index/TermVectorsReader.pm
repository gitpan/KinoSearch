use strict;
use warnings;

package KinoSearch::Index::TermVectorsReader;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN {
    __PACKAGE__->init_instance_vars(
        #constructor params / members
        schema   => undef,
        folder   => undef,
        seg_info => undef,
    );
}
our %instance_vars;

use KinoSearch::Index::DocVector;

sub doc_vec {
    my ( $self, $doc_num ) = @_;
    my $tv_in    = $self->_get_tv_in;
    my $tvx_in   = $self->_get_tvx_in;

    my $doc_vec = KinoSearch::Index::DocVector->new;

    $tvx_in->sseek( $doc_num * 8 );
    my $fileptr = $tvx_in->lu_read('Q');
    $tv_in->sseek($fileptr);

    my $num_fields = $tv_in->lu_read('V');

    while ( $num_fields-- ) {
        my ( $field_name, $field_string ) = $tv_in->lu_read('TT');
        $doc_vec->add_field_string( $field_name, $field_string );
    }

    return $doc_vec;
}

sub close { }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermVectorsReader

kino_TermVectorsReader*
new(...)
CODE:
{
    /* parse params */
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Index::TermVectorsReader::instance_vars");
    kino_Schema *schema = (kino_Schema*)extract_obj(
         args_hash, SNL("schema"), "KinoSearch::Schema");
    kino_Folder *folder = (kino_Folder*)extract_obj(
         args_hash, SNL("folder"), "KinoSearch::Store::Folder");
    kino_SegInfo *seg_info = extract_obj(args_hash, SNL("seg_info"),
        "KinoSearch::Index::SegInfo");

    RETVAL = kino_TVReader_new(schema, folder, seg_info);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_TermVectorsReader *self;
ALIAS:
    _get_tv_in    = 4
    _get_tvx_in   = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 4:  retval = kobj_to_pobj(self->tv_in);
             break;

    case 6:  retval = kobj_to_pobj(self->tvx_in);
             break;

    END_SET_OR_GET_SWITCH
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Index::TermVectorsReader - Read term vectors information.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


