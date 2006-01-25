package KinoSearch::Store::InStream;
use base qw( KinoSearch::Util::Class );
use KinoSearch::Util::ToolSet;

# members (InStream is an inside-out class)
my %start_offsets;
my %lengths;
my %parents;
my %filenames;

=begin comment

    my $instream = KinoSearch::Store::Instream->new( 
        $invindex, $filename, $filehandle, $offset, $length 
    );

Constructor.  Takes 3-5 arguments, and unlike most classes in the KinoSearch
suite, the arguments to the constructor are not labeled parameters.

The fourth argument, an offset, defaults to 0 if not supplied.  Non-zero
offsets get factored in when calling seek and tell.

The last argument, a length, is the length of the "file" in bytes.  Supplying
an explicit value is only essential for InStreams which are assigned to read a
portion of a compound file -- otherwise, the length gets auto-calculated
correctly.

=end comment
=cut

sub new {
    my ( $class, $invindex, $filename, $fh, $offset, $len ) = @_;

    # bless the supplied filehandle
    my $self = bless $fh, ref($class) || $class;

    # store information that will be needed when cloning
    $filenames{"$self"} = $filename;
    $parents{"$self"} = $invindex;

    # confirm/derive start_offset and set it
    $offset ||= 0;
    $start_offsets{"$self"} = $offset;

    # confirm/derive length and set it
    if ( !defined $len ) {
        CORE::seek( $self, 0, 2 );
        $len = ( CORE::tell $self) - $offset;
    }
    CORE::seek( $self, $offset, 0 );
    $lengths{"$self"} = $len;

    return $self;
}

# Read bytes into buffer. Takes two args: $instream->read( $buffer, $bytes );
sub read { CORE::read( $_[0], $_[1], $_[2] ) }

# Return the filehandle's position minus the offset.
sub tell {
    my $self = shift;
    return ( CORE::tell($self) ) - $start_offsets{"$self"};
}

# Seek to target plus the object's start offset.
sub seek {
    my ( $self, $to ) = @_;
    CORE::seek( $self, $to + $start_offsets{"$self"}, 0 );
}

# Return the length of the "file" in bytes.
sub length {
    my $self = shift;
    return $lengths{"$self"};
}

sub get_offset { $start_offsets{"$_[0]"} }

# Dupe the filehandle and create a new object around the dupe.  Seek the dupe
# to the same spot as the original.
sub clone_stream {
    my $self = shift;
    my $evil_twin = $parents{"$self"}->open_instream(
        $filenames{"$self"}, $start_offsets{"$self"}, $lengths{"$self"} );
    my $bookmark = CORE::tell($self);
    CORE::seek($evil_twin, $bookmark, 0);
    return $evil_twin;
}

sub DESTROY {    # not thread-safe
    my $self = shift;

    # clean up member variables
    delete $lengths{"$self"};
    delete $start_offsets{"$self"};
    delete $parents{"$self"};
    delete $filenames{"$self"};
}

sub close { CORE::close(shift) }

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Store::InStream

=begin comment

    @items = $instream->lu_read( TEMPLATE );

Read the items specified by TEMPLATE from the InStream.

=end comment
=cut

void
lu_read (fh, template_sv)
    PerlIO   *fh;  
    SV       *template_sv
PREINIT:
    STRLEN    tpt_len;      /* bytelength of template */
    char     *template;     /* ptr to a spot in the template */
    char     *tpt_end;      /* ptr to the end of the template */
    int       repeat_count; /* number of times to repeat sym */
    char      sym;          /* the current symbol in the template */
    char      countsym;     /* used when calculating repeat counts */
    IV        aIV;
    SV       *aSV;
    char      aChar;
    char*     string;
    STRLEN    len;
PPCODE:
{
    /* prepare template string pointers */
    template    = SvPV(template_sv, tpt_len);
    tpt_end     = SvEND(template_sv);

    repeat_count = 0;
    while (1) {
        if (repeat_count == 0) {
            /* fast-forward past space characters */
            while (*template == ' ' && template < tpt_end) {
                template++;
            }

            /* break out of the loop if we've exhausted the template */
            if (template == tpt_end) {
                break;
            }
            
            /* derive the current symbol and a possible digit repeat sym */
            sym      = *template++;
            countsym = *template;

            if (template == tpt_end) { 
                /* sym is last char in template, so process once */
                repeat_count = 1;
            }
            else if (countsym >= '0' && countsym <= '9') {
                /* calculate numerical repeat count */
                repeat_count = countsym - KINO_NUM_CHAR_OFFSET;
                countsym = *(++template);
                while (  template <= tpt_end 
                      && countsym >= '0' 
                      && countsym <= '9'
                ) {
                    repeat_count = (repeat_count * 10) 
                        + (countsym - KINO_NUM_CHAR_OFFSET);
                    countsym = *(++template);
                }
            }
            else { /* no numeric repeat count, so process sym only once */
                repeat_count = 1;
            }
        }

        /* thwart potential infinite loop */
        if (repeat_count < 1)
            Kino_confess(
                "Internal error: repeat_count < 1 -- Please notify author.");
        
        switch(sym) {

        case 'a': /* arbitrary binary data */
			len = repeat_count;
			repeat_count = 1;
            aSV = newSV(len + 1);
            SvCUR_set(aSV, len);
            SvPOK_on(aSV);
            string = SvPVX(aSV);
            Kino_IO_read_bytes(fh, string, len);
            break;

        case 'b': /* signed byte */
        case 'B': /* unsigned byte */
            aChar = Kino_IO_read_byte(fh);
            if (sym == 'b') 
                aIV = aChar;
            else
                aIV = (unsigned char)aChar;
            aSV = newSViv(aIV);
            break;

        case 'i': /* signed 32-bit integer */
            aSV = newSViv( (I32)Kino_IO_read_int(fh) );
            break;
            
        case 'I': /* unsigned 32-bit integer */
            aSV = newSVuv( Kino_IO_read_int(fh) );
            break;

        case 'Q': /* unsigned "64-bit integer" */
            aSV = newSVnv( Kino_IO_read_long(fh) );
            break;

        case 'T': /* string */
			len = Kino_IO_read_vint(fh);
            aSV = newSV(len + 1);
            SvCUR_set(aSV, len);
            SvPOK_on(aSV);
            string = SvPVX(aSV);
            Kino_IO_read_chars(fh, string, 0, len);
            break;

        case 'V': /* VInt */
            aSV = newSVuv( Kino_IO_read_vint(fh) );
            break;

        case 'W': /* VLong */
            aSV = newSVnv( Kino_IO_read_vlong(fh) );
            break;

        default: 
            Kino_confess("Invalid type in template: '%c'", sym);
        }

        /* Put a scalar on the stack, use up one symbol or repeater */
        XPUSHs( sv_2mortal(aSV) );
        repeat_count -= 1;
    }
}

__H__


#ifndef H_KINOSEARCH_STORE_INSTREAM
#define H_KINOSEARCH_STORE_INSTREAM 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"
#include "KinoSearchUtilEndianUtils.h"

/* Detect whether we're on an ASCII or EBCDIC machine. */
#if '0' == 240
#define KINO_NUM_CHAR_OFFSET 240
#else
#define KINO_NUM_CHAR_OFFSET 48
#endif

char   Kino_IO_read_byte  (PerlIO*);
U32    Kino_IO_read_int   (PerlIO*);
double Kino_IO_read_long  (PerlIO*);
U32    Kino_IO_read_vint  (PerlIO*);
double Kino_IO_read_vlong (PerlIO*);
void   Kino_IO_read_chars (PerlIO*, char*, STRLEN, STRLEN);
void   Kino_IO_read_bytes (PerlIO*, char*, STRLEN);

#endif /* include guard */

__C__

#include "KinoSearchStoreInStream.h"

char
Kino_IO_read_byte (PerlIO *fh) {
    char c;
    int  check_val;

    check_val = PerlIO_read(fh, &c, 1);
    if (check_val != 1)
        Kino_confess("Kino_IO_read_byte error: %d", check_val);
     return c;
}

U32
Kino_IO_read_int (PerlIO *fh) {
    unsigned char buf[4];
    int           check_val;

    check_val = PerlIO_read(fh, &buf, 4);
    if (check_val < 4)
        Kino_confess("Kino_IO_read_long error: %d", check_val);
 
    return Kino_decode_bigend_U32(buf);
}

double
Kino_IO_read_long (PerlIO* fh) {
    unsigned char buf[8];
    int           check_val;
    double        aDouble;

    check_val = PerlIO_read(fh, &buf, 8);
    if (check_val < 8)
        Kino_confess("Kino_IO_read_long error: %d", check_val);
 
    /* get high 4 bytes, multiply by 2**32 */
    aDouble = Kino_decode_bigend_U32(buf);
    aDouble = aDouble * pow(2.0, 32.0);
    
    /* decode low four bytes as unsigned int and add to total */
    aDouble += Kino_decode_bigend_U32(&buf[4]);

    return aDouble;
}

/* read in a Variable INTeger, stored in 1-5 bytes */
U32 
Kino_IO_read_vint (PerlIO *fh) {
    unsigned char aUChar;
    int           bitshift;
    int           check_val;
    U32           aU32;

    /* start by reading one byte; use the lower 7 bits */
    check_val = PerlIO_read(fh, &aUChar, 1);
    if (check_val < 1)
        Kino_confess("Kino_IO_read_vint error: %d", check_val);
    aU32 = aUChar & 0x7f;

    /* keep reading and shifting as long as the high bit is set */
    for (bitshift = 7; (aUChar & 0x80) != 0; bitshift += 7) {
        check_val = PerlIO_read(fh, &aUChar, 1);
        if (check_val < 1)
            Kino_confess("Kino_IO_read_vint error: %d", check_val);
         aU32 |= (aUChar & 0x7f) << bitshift;
    }
    return aU32;
}

double
Kino_IO_read_vlong (PerlIO *fh) {
    unsigned char aUChar;
    double        aDouble;
    int           bitshift;
    int           check_val;

    check_val = PerlIO_read(fh, &aUChar, 1);
    if (check_val != 1)
        Kino_confess("Kino_IO_read_vlong error: %d", check_val);
    aDouble = aUChar & 0x7f;
    for (bitshift = 7; (aUChar & 0x80) != 0; bitshift += 7) {
        check_val = PerlIO_read(fh, &aUChar, 1);
        if (check_val != 1)
            Kino_confess("Kino_IO_read_vlong error: %d", check_val);
        aDouble += (aUChar & 0x7f) * pow(2, bitshift);
    }
    return aDouble;
}

/* This is almost identical to read_bytes, but that may change.  It should
 * be used whenever Lucene character data is being read, typically after
 * read_vint as part of a String read. If and when a change does come, it will
 * be a lot easier to track down all the relevant code fragments if read_chars
 * gets used consistently. */
void
Kino_IO_read_chars (PerlIO *fh, char *buf, STRLEN start, STRLEN len) {
    int check_val;
	
	buf += start;
    check_val = PerlIO_read(fh, buf, len);
    if (check_val < len)
        Kino_confess("Kino_IO_read_bytes error: %d", check_val);
}

void
Kino_IO_read_bytes (PerlIO *fh, char* buf, STRLEN len) {
    int check_val;
    
    check_val = PerlIO_read(fh, buf, len);
    if (check_val < len)
        Kino_confess("Kino_IO_read_bytes error: %d", check_val);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Store::InStream - filehandles for reading invindexes

=head1 SYNOPSIS
    
    # isa blessed filehandle
    
    my $instream  = $invindex->open_instream( $filehandle, $offset, $length );
    my @ten_vints = $instream->lu_read('V10');

=head1 DESCRIPTION

The InStream class abstracts out all input operations to KinoSearch.

InStream is implemented as a inside-out object around a blessed filehandle.
It would almost be possible to use an ordinary filehandle, but the
objectification is necessary because InStreams have to be capable of
pretending that they are acting upon a distinct file when in reality they may
be reading only a portion of a compound file.

For the template used by lu_read, see InStream's companion,
L<OutStream|KinoSearch::Store::OutStream>.

=head1 TODO

It would be nice if filehandles against compound files could behave as if the
sub-file was an ordinary file with regards to seek, tell and eof.  This could
be done using PerlIO::via.  Unfortunately, pure Perl PerlIO::via
implementations of InStream incur a 60% speed hit when reading, since it's
required that you override READ or FILL -- we don't need to do that; we only
want to override SEEK, TELL, and EOF.  If this TODO gets done, it will have to
get done in XS using a custom PerlIO layer.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut

