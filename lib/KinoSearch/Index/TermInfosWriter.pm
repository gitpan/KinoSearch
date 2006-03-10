package KinoSearch::Index::TermInfosWriter;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use KinoSearch::Index::TermInfo;
use Clone 'clone';

use constant FORMAT        => -2;
use constant SKIP_INTERVAL => 16;    # if changes, must also change in XS

our $INDEX_INTERVAL = 1024;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    invindex => undef,
    seg_name => undef,
    is_index => 0,
    # members
    outstream => undef,
    other     => undef,
    # NOTE: this value forces the first field_num in the .tii file to -1.
    # Do not change it.
    last_termstring => "\xff\xff",
    last_fieldnum   => -1,
    last_tinfo      => undef,
    last_tis_ptr    => 0,
    size            => 0,
);

sub init_instance {
    my $self = shift;

    # give object a TermInfo to compare on the first call to add()
    $self->{last_tinfo} = KinoSearch::Index::TermInfo->new( 0, 0, 0, 0, 0 );

    # open an outstream
    my $suffix = $self->{is_index} ? 'tii' : 'tis';
    $self->{outstream}
        = $self->{invindex}->open_outstream("$self->{seg_name}.$suffix");
    $self->{outstream}
        ->lu_write( 'iQii', FORMAT, 0, $INDEX_INTERVAL, SKIP_INTERVAL );

    # create a doppleganger which will write the .tii file
    if ( !$self->{is_index} ) {
        $self->{other} = __PACKAGE__->new(
            invindex => $self->{invindex},
            seg_name => $self->{seg_name},
            is_index => 1,
        );
        $self->{other}->{other} = $self;
    }
}

# Write out a term/terminfo combo.
sub add {
    my ( $self, $termstring, $tinfo ) = @_;
    my $last_tinfo = $self->{last_tinfo};

    # write a subset of the entries to the .tii index
    if ( $self->{size} % $INDEX_INTERVAL == 0 and !$self->{is_index} ) {
        $self->{other}->add( $self->{last_termstring}, $last_tinfo );
    }

    _add_helper(
        $self->{outstream}, $tinfo, $self->{last_tinfo},
        $termstring,        $self->{last_termstring}
    );

    # The .tii index file gets a pointer to the location of the primary
    if ( $self->{is_index} ) {
        my $tis_ptr = $self->{other}{outstream}->tell;
        $self->{outstream}->lu_write( 'W', $tis_ptr - $self->{last_tis_ptr} );
        $self->{last_tis_ptr} = $tis_ptr;
    }

    # track number of terms
    $self->{size}++;

    # remember for delta encoding
    $self->{last_termstring} = $termstring;
    $self->{last_tinfo}      = $tinfo;
}

sub finish {
    my $self = shift;

    # rewind to near the beginning of the file and write size
    $self->{outstream}->seek(4);
    $self->{outstream}->lu_write( 'Q', $self->{size} );
    if ( !$self->{is_index} ) {
        $self->{other}->finish;
    }
    $self->{outstream}->close;
}

sub DESTROY {
    my $self = shift;
    undef $self->{other} if defined $self->{other};    # break circular ref
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::TermInfosWriter

#define SKIP_INTERVAL 16

void
_add_helper(outstream, tinfo, last_tinfo, termstring_sv, last_termstring_sv)
    OutStream *outstream;
    TermInfo  *tinfo;
    TermInfo  *last_tinfo;
    SV        *termstring_sv
    SV        *last_termstring_sv
PREINIT:
    STRLEN    termstring_len;
    char     *termstring_str;
    STRLEN    last_tstring_len;
    char     *last_tstring_str;
    IV        field_num;
    IV        overlap;
    char     *diff_start_str;
    STRLEN    diff_len;
PPCODE:
{
    /* extract string pointers and string lengths */
    termstring_str   = SvPV( termstring_sv, termstring_len );
    last_tstring_str = SvPV( last_termstring_sv, last_tstring_len );

    /* to obtain field number, decode packed 'n' at top of termstring */
    field_num = (I16)Kino_decode_bigend_U16(termstring_str);

    /* move past field_num */
    termstring_str   += KINO_FIELD_NUM_LEN;
    last_tstring_str += KINO_FIELD_NUM_LEN;
    termstring_len   -= KINO_FIELD_NUM_LEN;
    last_tstring_len -= KINO_FIELD_NUM_LEN;

    /* count how many bytes the strings share at the top */ 
    overlap = Kino_StrHelp_string_diff(last_tstring_str, termstring_str,
        last_tstring_len, termstring_len);
    diff_start_str = termstring_str + overlap;
    diff_len       = termstring_len - overlap;

    /* write number of common bytes */
    outstream->write_vint(outstream, overlap);

    /* write common bytes */
    outstream->write_string(outstream, diff_start_str, diff_len);
    
    /* write field number and doc_freq */
    outstream->write_vint(outstream, field_num);
    outstream->write_vint(outstream, tinfo->doc_freq);

    /* delta encode filepointers */
    outstream->write_vlong(outstream, 
        (tinfo->frq_fileptr - last_tinfo->frq_fileptr) );
    outstream->write_vlong(outstream, 
        (tinfo->prx_fileptr - last_tinfo->prx_fileptr) );

    /* write skipdata */
    if (tinfo->doc_freq >= SKIP_INTERVAL)
        outstream->write_vint(outstream, tinfo->skip_offset);
}


__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::TermInfosWriter - write a term dictionary

=head1 DESCRIPTION

The TermInfosWriter write both parts of the term dictionary.  The primary
instance creates a shadow TermInfosWriter that writes the index.

=head TODO

Find the optimum TermIndexInterval.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut

