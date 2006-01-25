package KinoSearch::Index::PostingsWriter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use constant FORMAT         => -2;
use constant INDEX_INTERVAL => 128;
use constant SKIP_INTERVAL  => 16;

use Sort::External;
use File::Temp qw();
use File::Spec;
use KinoSearch::Index::TermInfo;
use KinoSearch::Index::TermInfosWriter;

our %instance_vars = (
    # constructor params / members
    invindex => undef,
    seg_name => undef,

    # members
    temp_dir       => undef,
    postings_cache => undef,
);

sub init_instance {
    my $self = shift;

    # create a temp directory
    my $working_dir =
        defined $self->{invindex}->{path}
        ? $self->{invindex}->{path}
        : File::Spec->tmpdir;
    $self->{temp_dir} = File::Temp::tempdir(
        "kinotemp_XXXXXX",
        DIR     => $working_dir,
        CLEANUP => 1,
    );

    # create a Sort::External object which autosorts the posting list cache
    $self->{postings_cache} = Sort::External->new(
        -working_dir   => $self->{temp_dir},
        -mem_threshold => 2**24,
    );
}

# Add the postings to the segment.  Postings are serialized and dumped into a
# Sort::External sort pool.  The actual writing takes place later.
sub add_postings {
    my ( $self, $doc_num, $field_num, $tokens ) = @_;

    # associate each term text with an array of U32 representing its positions
    my $pos = 0;
    my %positions;
    {
        no warnings 'uninitialized';
        for (@$tokens) {
            next if $_ eq '';
            $positions{$_} .= pack( 'I', $pos++ );
        }
    }

    # dump serialized postings into the Sort::External pool.
    my $serialized = _serialize_postings( \%positions, $doc_num, $field_num );
    $self->{postings_cache}->feed(@$serialized);
}

=for comment

Process all the postings in the sort pool.  Generate the freqs and positions
files.  Hand off data to TermInfosWriter for the generating the term
dictionaries.

=cut

sub write_postings {
    my $self = shift;
    my ( $invindex, $seg_name ) = @{$self}{ 'invindex', 'seg_name' };
    my ( $posting, $termstring, $freq, $doc_num );
    my $last_termstring   = "\0\0";
    my $last_doc_num      = 0;
    my $doc_freq          = -1;       # due to 1-iter lag
    my $tinfo             = undef;
    my $last_skip_doc     = 0;
    my $last_skip_frq_ptr = 0;
    my $last_skip_prx_ptr = 0;
    my @skipdata;

    # sort the serialized postings
    my $postings_cache = $self->{postings_cache};
    $postings_cache->finish;

    # prepare various outputs
    my $tinfos_writer = KinoSearch::Index::TermInfosWriter->new(
        invindex => $invindex,
        seg_name => $seg_name,
    );
    my $frq_out = $invindex->open_outstream("$seg_name.frq");
    my $prx_out = $invindex->open_outstream("$seg_name.prx");

    # each loop is one field, one term, one doc_num, many positions
    my $iter = 0;
    while ( defined( $posting = $postings_cache->fetch ) or goto FINAL_ITER )
    {
        # each loop represents a doc to add to the doc_freq for a given term
        $iter++;
        $doc_freq++;    # lags by 1 iter

        # break up the serialized posting into its parts.
        # $posting gets whittled down until it is only the positions string.
        _deserialize( $posting, $termstring, $doc_num, $freq );

        # on the first iter, prime the "heldover" variables
        if ( $iter == 1 ) {
            $last_termstring = $termstring;
            $tinfo           = KinoSearch::Index::TermInfo->new(
                0,                 # doc_freq
                $frq_out->tell,    # frq_fileptr
                $prx_out->tell,    # prx_fileptr
                $frq_out->tell,    # skip_offset
                0,                 # index_fileptr
            );
        }
        elsif ( $iter == -1 ) {    # never true; can only get here from a goto
                # prepare to clear out buffers and exit loop
        FINAL_ITER: {
                $iter       = -1;
                $termstring = "\0\0";
                $doc_freq++;
            }
        }

        # for common terms, create skipdata (unused by KinoSearch at present)
        if ( ( $doc_freq + 1 ) % SKIP_INTERVAL == 0 ) {
            my $frq_ptr = $frq_out->tell;
            my $prx_ptr = $prx_out->tell;
            push @skipdata,
                (
                $last_doc_num - $last_skip_doc,
                $frq_ptr - $last_skip_frq_ptr,
                $prx_ptr - $last_skip_prx_ptr,
                );
            $last_skip_doc     = $last_doc_num;
            $last_skip_frq_ptr = $frq_ptr;
            $last_skip_prx_ptr = $prx_ptr;
        }

        # if either the term or fieldnum changes, process the last term
        if ( $termstring ne $last_termstring ) {

            # take note of where we are for recording in the term dictionary
            my $frq_ptr = $frq_out->tell;
            my $prx_ptr = $prx_out->tell;

            # write skipdata if there is any
            if (@skipdata) {
                # kludge to compensate for doc_freq's 1-iter lag
                if ( ( $doc_freq + 1 ) % SKIP_INTERVAL == 0 ) {
                    splice @skipdata, -3;
                }

                if (@skipdata) {
                    # tell TinfosWriter about the non-zero skip amount
                    $tinfo->set_skip_offset(
                        $frq_ptr - $tinfo->get_frq_fileptr );

                    # write an extra block of VInts to the frq file
                    $frq_out->lu_write( 'V' x scalar @skipdata, @skipdata );

                    # update the filepointer for the file we just wrote to.
                    $frq_ptr = $frq_out->tell;
                }
                @skipdata = ();
            }

            # init skip data in preparation for the next term
            $last_skip_doc     = 0;
            $last_skip_frq_ptr = $frq_ptr;
            $last_skip_prx_ptr = $prx_ptr;

            # hand off to TermInfosWriter
            $tinfo->set_doc_freq($doc_freq);
            $tinfos_writer->add( $last_termstring, $tinfo );
            $tinfo = KinoSearch::Index::TermInfo->new(
                0,           # doc_freq
                $frq_ptr,    # frq_fileptr
                $prx_ptr,    # prx_fileptr
                0,           # skip_offset
                0,           # index_fileptr
            );

            # start each term afresh.
            $last_termstring = $termstring;
            $doc_freq        = 0;
            $last_doc_num    = 0;
        }

        # break out of loop on last iter before writing invalid data
        last if $iter == -1;

        # write positions data
        _write_positions( $prx_out, $posting );

        # write freq data...
        # doc_code is delta doc_num, shifted left by 1.
        if ( $freq == 1 ) {
            # set low bit of doc_code to 1 to indicate freq of 1
            $frq_out->lu_write( 'V',
                ( ( ( $doc_num - $last_doc_num ) * 2 ) + 1 ),
            );
        }
        else {
            # leave low bit of doc_code at 0, record explicit freq
            $frq_out->lu_write( 'VV', ( ( $doc_num - $last_doc_num ) * 2 ),
                $freq, );
        }

        # remember last doc num because we need it for delta encoding
        $last_doc_num = $doc_num;
    }

    $frq_out->close;
    $prx_out->close;
    $tinfos_writer->finish;
}

sub finish { }

1;

__END__
__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::PostingsWriter		


=begin comment

Pack all the information about a posting into a scalar.

The serialization algo is designed so that postings emerge from the sort
pool in the order ideal for writing an index after a  simple lexical sort.
The concatenated components are:

    field number
    term text 
    document number
    positions (C array)
    term length

All integers use big-endian format.

=end comment
=cut

void 
_serialize_postings(pos_hash, doc_num, field_num)
    HV      *pos_hash;
    U32      doc_num;
    U16      field_num;
PREINIT:
    char     doc_num_buf[4];
    char     field_num_buf[2];
    U16      term_len_U16;
    char     term_len_buf[4];
    HE      *he;
    char    *term_str;
    STRLEN   term_len;
    SV      *pos_string_sv;
    char    *pos_string;
    STRLEN   pos_string_len;
    AV      *out_av;
    SV      *serialized_sv;
PPCODE:
{
    /* prepare doc num and field num in anticipation of upcoming loop */
    Kino_encode_bigend_U32(doc_num, doc_num_buf);
    Kino_encode_bigend_U16(field_num, field_num_buf);

    /* retrieve %positions hash,  create output array */
    out_av = newAV();
    
    /* pack a scalar */
    while (he = hv_iternext(pos_hash)) {
        term_str     = HePV(he, term_len);
        term_len_U16 = term_len;
        Kino_encode_bigend_U16(term_len_U16, term_len_buf);

        pos_string_sv = HeVAL(he);
        serialized_sv = newSVpvn(field_num_buf, KINO_FIELD_NUM_LEN);
        sv_catpvn(serialized_sv, term_str, term_len);
        sv_catpvn(serialized_sv, doc_num_buf, 4);
        sv_catsv(serialized_sv, pos_string_sv);
        sv_catpvn(serialized_sv, term_len_buf, 2);
        av_push(out_av, serialized_sv);
    }

    XPUSHs(sv_2mortal(newRV_noinc( (SV*)out_av )) );
}

=begin comment

Pull apart a serialized posting into its component parts.

Scalars are modified in place, which isn't Perl-ish, but this is
performance-critical code.

=end comment
=cut

void 
_deserialize ( posting_sv, termstring_sv, doc_num_sv, freq_sv )
    SV      *posting_sv 
    SV      *termstring_sv
    SV      *doc_num_sv 
    SV      *freq_sv 
PREINIT:
    STRLEN   posting_len;        /* length of the serialized posting */
    char    *posting_str;        /* ptr to PV of the serialized posting */
    char    *termstring_len_ptr;
    STRLEN   termstring_len;     /* length of the term, with field num */
    IV       doc_num;
    IV       freq;	             /* freq of term in field */
PPCODE:
{
    /* extract pointer from serialized posting */
    posting_str = SvPV(posting_sv, posting_len);

    /* extract termstring_len, decoding packed 'n', assign termstring */
    termstring_len_ptr = posting_str + posting_len - 2;
    termstring_len     
        = Kino_decode_bigend_U16(termstring_len_ptr) + KINO_FIELD_NUM_LEN;
    sv_setpvn(termstring_sv, posting_str, termstring_len);

    /* extract and assign doc_num, decoding packed 'N' */
    posting_str  += termstring_len;
    doc_num      = Kino_decode_bigend_U32(posting_str);
    posting_str  += 4;
    sv_setiv(doc_num_sv, doc_num);

    /* whack termstring_len off the end of the posting */
    posting_len -= 2; 
    SvCUR_set(posting_sv, posting_len);
    
    /* whack field_num/term text off the front, leaving only the positions */
    sv_chop(posting_sv, posting_str);

    /* calculate freq by counting the number of positions, assign */
    freq = (posting_len - termstring_len - 4) / 4;
    sv_setiv(freq_sv, freq);
}

=begin comment

Write out the positions data using the delta encoding specified by the Lucene 
file format.

=end comment
=cut

void
_write_positions ( prx_fh, positions_sv )
    PerlIO  *prx_fh;
    SV      *positions_sv
PREINIT:
    STRLEN   positions_len;
    char    *positions;
    U32     *current_pos_ptr;
    U32     *end;
    U32      last_pos;
    U32      pos_delta;
PPCODE:
{
    positions = SvPV(positions_sv, positions_len);

    /* Extract native 32 bit unsigned integers from positions_sv. positions_sv
     * was originally built up using the equivalent of pack('I*', @positions),
     * and pack template 'I' is a U32.
     */
    current_pos_ptr = (U32*)positions;
    end             = current_pos_ptr + (positions_len / 4);
    last_pos        = 0;
    while (current_pos_ptr < end) {
        /* get delta and write out as VInt */
        pos_delta = *current_pos_ptr - last_pos;
        Kino_IO_write_vint(prx_fh, pos_delta);

        /* advance pointers */
        last_pos = *current_pos_ptr;
        current_pos_ptr++;
    }
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Index::PostingsWriter - write postings data to an invindex

=head1 DESCRIPTION

PostingsWriter creates posting lists.  It writes the frequency and and
positional data files, plus feeds data to TermInfosWriter.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut

