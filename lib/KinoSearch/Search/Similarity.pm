package KinoSearch::Search::Similarity;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::CClass );

our %instance_vars = __PACKAGE__->init_instance_vars();

# See _float_to_byte.
*encode_norm = *_float_to_byte;
*decode_norm = *_byte_to_float;

# Calculate the Inverse Document Frequecy for one or more Term in a given
# collection (the Searcher represents the collection).
#
# If multiple Terms are supplied, their idfs are summed.
sub idf {
    my ( $self, $term_or_terms, $searcher ) = @_;
    my $max_doc = $searcher->max_doc;
    my $terms
        = ref $term_or_terms eq 'ARRAY' ? $term_or_terms : [$term_or_terms];

    return 1 unless $max_doc;    # guard against log of zero error

    # accumulate IDF
    my $idf = 0;
    for my $term (@$terms) {
        my $doc_freq = $searcher->doc_freq($term);
        $idf += 1 + log( $max_doc / ( 1 + $searcher->doc_freq($term) ) );
    }
    return $idf;
}

# Normalize a Query's weight so that it is comparable to other Queries.
sub query_norm {
    my ( $self, $sum_of_squared_weights ) = @_;
    return 0 if ( $sum_of_squared_weights == 0 );  # guard against div by zero
    return ( 1 / sqrt($sum_of_squared_weights) );
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::Similarity     

Similarity*
new(...)
CODE:
    RETVAL = Kino_Sim_new();
OUTPUT: RETVAL

=for comment

Provide a normalization factor for a field based on the square-root of the
number of terms in it.

=cut

float
lengthnorm(sim, num_terms)
    Similarity *sim;
    U32         num_terms;
CODE:
    num_terms = num_terms < 100 ? 100 : num_terms;
    RETVAL = (float)1 / sqrt(num_terms);
OUTPUT: RETVAL

=for comment

Return a score factor based on the frequency of a term in a given document.
The default implementation is sqrt(freq).  Other implementations typically
produce ascending scores with ascending freqs, since the more times a doc
matches, the more relevant it is likely to be.

=cut

float
tf(sim, freq)
    Similarity *sim;
    U32         freq;
CODE:
    RETVAL = sim->tf(sim, freq);
OUTPUT: RETVAL


=for comment

_float_to_byte and _byte_to_float encode and decode between 32-bit IEEE
floating point numbers and a 5-bit exponent, 3-bit mantissa float.  The range
covered by the single-byte encoding is 7x10^9 to 2x10^-9.  The accuracy is
about one significant decimal digit.

=cut

SV*
_float_to_byte(sim, f) 
    Similarity *sim;
    float       f;
PREINIT:
    char b;
CODE:
    b      = Kino_Sim_float2byte(sim, f);
    RETVAL = newSVpv(&b, 1);
OUTPUT: RETVAL

float
_byte_to_float(sim, b) 
    Similarity *sim;
    char        b;
CODE:
    RETVAL = Kino_Sim_byte2float(sim, b);
OUTPUT: RETVAL


=for comment

The norm_decoder caches the 256 possible byte => float pairs, obviating the
need to call decode_norm over and over for a scoring implementation that
knows how to use it.

=cut

SV*
get_norm_decoder(sim)
    Similarity *sim;
CODE:
    RETVAL = newSVpv( (char*)sim->norm_decoder, (256 * sizeof(float)) );
OUTPUT: RETVAL

float
coord(sim, overlap, max_overlap)
    Similarity *sim;
    U32         overlap;
    U32         max_overlap;
CODE:
    RETVAL = sim->coord(sim, overlap, max_overlap);
OUTPUT: RETVAL

void
DESTROY(sim)
    Similarity *sim;
PPCODE:
    Kino_Sim_destroy(sim);

    
__H__

#ifndef H_KINO_SIMILARITY
#define H_KINO_SIMILARITY 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilMemManager.h"

typedef struct similarity {
    float  (*tf)(struct similarity*, float);
    float  (*coord)(struct similarity*, U32, U32);
    float   *norm_decoder;
} Similarity;

Similarity* Kino_Sim_new();
float Kino_Sim_default_tf(Similarity*, float);
char  Kino_Sim_float2byte(Similarity*, float);
float Kino_Sim_byte2float(Similarity*, char);
float Kino_Sim_coord(Similarity*, U32, U32);
void  Kino_Sim_destroy(Similarity*);

#endif /* include guard */

__C__

#include "KinoSearchSearchSimilarity.h"

Similarity*
Kino_Sim_new() {
    int            i;
    unsigned char  aUChar;
    Similarity    *sim;

    Kino_New(0, sim, 1, Similarity);

    /* cache decoded norms */
    Kino_New(0, sim->norm_decoder, 256, float);
    for (i = 0; i < 256; i++) {
        aUChar = i;
        sim->norm_decoder[i] = Kino_Sim_byte2float(sim, (char)aUChar);
    }

    sim->tf    = Kino_Sim_default_tf;
    sim->coord = Kino_Sim_coord;
    return sim;
}

float
Kino_Sim_default_tf(Similarity *sim, float freq) {
    return( sqrt(freq) );
}

char 
Kino_Sim_float2byte(Similarity *sim, float f) {
    char norm;
    I32  mantissa;
    I32  exponent;
    I32  bits;

    if (f < 0.0)
        f = 0.0;

    if (f == 0.0) {
        norm = 0;
    }
    else {
        bits = *(I32*)&f;
        mantissa = (bits & 0xffffff) >> 21;
        exponent = (((bits >> 24) & 0x7f)-63) + 15;

        if (exponent > 31) {
            exponent = 31;
            mantissa = 7;
        }
        if (exponent < 0) {
            exponent = 0;
            mantissa = 1;
        }
         
        norm = (char)((exponent << 3) | mantissa);
    }

    return norm;
}

float
Kino_Sim_byte2float(Similarity *sim, char b) {
    I32 mantissa;
    I32 exponent;
    I32 result;

    if (b == 0) {
        result = 0;
    }
    else {
        mantissa = b & 7;
        exponent = (b >> 3) & 31;
        result = ((exponent+(63-15)) << 24) | (mantissa << 21);
    }
    
    return *(float*)&result;
}

/* Calculate a score factor based on the number of terms which match. */
float
Kino_Sim_coord(Similarity *sim, U32 overlap, U32 max_overlap) {
    if (max_overlap == 0)
        return 1;
    return (float)overlap / (float)max_overlap;
}

void
Kino_Sim_destroy(Similarity *sim) {
    Kino_Safefree(sim->norm_decoder);
    Kino_Safefree(sim);
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Search::Similarity - calculate how closely two items match

=head1 DESCRIPTION

The Similarity class encapsulates some of the math used when calculating
scores.

=head1 SEE ALSO

The Lucene equivalent of this class provides a thorough discussion of the
Lucene scoring algorithm, which KinoSearch implements.  

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut


