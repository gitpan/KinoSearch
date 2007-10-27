use strict;
use warnings;

package KinoSearch::Search::Similarity;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

our %instance_vars = ();

sub length_norm {
    my ( $self, $num_tokens ) = @_;
    return 0 unless $num_tokens;
    return 1 / sqrt($num_tokens);
}

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

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::Similarity     

=begin comment

Rather than attempt to serialize a Similarity, we just create a new one.  The
only meaningful variable is the class name, and Storable takes care of that.

=end comment
=cut

kino_Similarity*
new(class_name)
    const classname_char *class_name;
CODE:
    RETVAL = kino_Sim_new(class_name);
OUTPUT: RETVAL

float
tf(self, freq)
    kino_Similarity *self;
    chy_u32_t  freq;
CODE:
    RETVAL = Kino_Sim_TF(self, freq);
OUTPUT: RETVAL


SV*
encode_norm(self, f) 
    kino_Similarity *self;
    float f;
CODE:
{
    const chy_u32_t byte = Kino_Sim_Encode_Norm(self, f);
    RETVAL = newSVuv(byte);
}
OUTPUT: RETVAL

float
decode_norm(self, byte) 
    kino_Similarity *self;
    chy_u32_t byte;
CODE:
    RETVAL = Kino_Sim_Decode_Norm(self, byte);
OUTPUT: RETVAL

float
query_norm(self, sum_of_squared_weights)
    kino_Similarity *self;
    float sum_of_squared_weights;
CODE:
    RETVAL = Kino_Sim_Query_Norm(self, sum_of_squared_weights);
OUTPUT: RETVAL

=for comment

The norm_decoder caches the 256 possible byte => float pairs, obviating the
need to call decode_norm over and over for a scoring implementation that
knows how to use it.

=cut

SV*
get_norm_decoder(self)
    kino_Similarity *self;
CODE:
    RETVAL = newSVpvn( (char*)self->norm_decoder, (256 * sizeof(float)) );
OUTPUT: RETVAL

float
coord(self, overlap, max_overlap)
    kino_Similarity *self;
    chy_u32_t overlap;
    chy_u32_t max_overlap;
CODE:
    RETVAL = Kino_Sim_Coord(self, overlap, max_overlap);
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Search::Similarity - Calculate how closely two things match.

=head1 SYNOPSIS

    # ./MySimilarity.pm
    package MySimilarity;

    sub length_norm { 
        my ( $self, $num_tokens ) = @_;
        return $num_tokens == 0 ? 1 : log($num_tokens) + 1;
    }

    # ./MySchema.pm
    package MySchema;
    use base qw( KinoSearch::Schema );
    use MySimilarity;
    
    sub similarity { MySimilarity->new }

=head1 DESCRIPTION

KinoSearch uses a close approximation of boolean logic for determining which
documents match a given query; then it uses a variant of the vector-space
model for calculating scores.  Much of the math used when calculating these
scores is encapsulated within the Similarity class.

Similarity objects are are used internally by KinoSearch's indexing and
scoring classes.  They are assigned using L<KinoSearch::Schema> and
L<KinoSearch::FieldSpec>.

Only one method is publicly exposed at present.

=head1 SUBCLASSING

To build your own Similarity implmentation, provide a new implementation of
length_norm() under a new class name.  Similarity's internal constructor will
inherit properly.  

Similarity is implemented as a C-struct object, so you can't add any member
variables to it.

=head1 METHODS 

=head2 length_norm 

    my $multiplier = $sim->length_norm($num_tokens);

After a field is broken up into terms at index-time, each term must be
assigned a weight.  One of the factors in calculating this weight is the
number of tokens that the original field was broken into.

Typically, we assume that the more tokens in a field, the less important any
one of them is -- so that, e.g. 5 mentions of "Kafka" in a short article 
are given more heft than 5 mentions of "Kafka" in an entire book.  The default
implementation of length_norm expresses this using an inverted square root.  

However, the inverted square root has a tendency to reward very short fields
highly, which isn't always appropriate for fields you expect to have a lot of
tokens on average.  See L<KSx::Search::LongFieldSim> for a discussion.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut


