use strict;
use warnings;

package KinoSearch::Search::TermQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

our %instance_vars = (
    # inherited
    boost => 1.0,

    # params / members
    term => undef,
);

BEGIN { __PACKAGE__->ready_get(qw( term )) }

use KinoSearch::Util::ToStringUtils qw( boost_to_string );

sub init_instance {
    my $self = shift;
    confess("parameter 'term' is not a KinoSearch::Index::Term")
        unless a_isa_b( $self->{term}, 'KinoSearch::Index::Term' );
}

sub make_weight {
    my ( $self, $searcher ) = @_;
    my $weight = KinoSearch::Search::TermWeight->new(
        parent   => $self,
        searcher => $searcher,
    );
}

sub extract_terms { shift->{term} }

sub to_string {
    my ( $self, $proposed_field ) = @_;
    my $field = $self->{term}->get_field;
    my $string = $proposed_field eq $field ? '' : "$field:";
    $string .= $self->{term}->get_text . boost_to_string( $self->{boost} );
    return $string;
}

package KinoSearch::Search::TermWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

use KinoSearch::Search::TermScorer;

our %instance_vars = (
    # inherited
    searcher   => undef,
    parent     => undef,
    similarity => undef,

    # members
    idf               => undef,
    raw_impact        => undef,
    query_norm_factor => undef,
    normalized_impact => undef,
);

sub init_instance {
    my $self  = shift;
    my $term  = $self->{parent}{term};
    my $field = $term->get_field;

    # don't keep searcher around; it interferes with serialization
    my $searcher = delete $self->{searcher};

    # retrieve the correct Similarity for the Term's field
    my $sim = $self->{similarity} = $searcher->get_schema->fetch_sim($field);

    # store IDF
    my $idf = $self->{idf} = $sim->idf( $term, $searcher );

    # The score of any document is approximately equal to:
    #
    #    ( tf_d * idf_t / norm_d ) * ( tf_q * idf_t / norm_q )
    #
    # Here we add in the first IDF, plus user-supplied boost.
    #
    # The second clause is factored in by the call to
    # perform_query_normalization().
    #
    # tf_d and norm_d can only be added by the Scorer, since they are
    # per-document.
    $self->{raw_impact} = $idf * $self->{parent}->get_boost;

    # make final preparations
    $self->perform_query_normalization($searcher);
}

sub sum_of_squared_weights { shift->{raw_impact}**2 }

sub normalize {
    my ( $self, $query_norm_factor ) = @_;
    $self->{query_norm_factor} = $query_norm_factor;

    # Multiply raw impact by ( tf_q * idf_q / norm_q )
    #
    # Note: factoring in IDF a second time is correct.  See formula.
    $self->{normalized_impact}
        = $self->{raw_impact} * $self->{idf} * $query_norm_factor;
}

sub get_value { shift->{normalized_impact} }

sub scorer {
    my ( $self, $reader ) = @_;
    my $term = $self->{parent}{term};
    my $plist = $reader->posting_list( term => $term );
    return unless defined $plist;
    return unless $plist->get_doc_freq;

    return $plist->make_scorer(
        similarity   => $self->{similarity},
        weight       => $self,
        weight_value => $self->get_value,
    );
}

1;

__END__

=head1 NAME

KinoSearch::Search::TermQuery - Match individual Terms.

=head1 SYNOPSIS

    my $term = KinoSearch::Index::Term->new( $field, $term_text );
    my $term_query = KinoSearch::Search::TermQuery->new(
        term => $term,
    );
    my $hits = $searcher->search( query => $term_query );

=head1 DESCRIPTION 

TermQuery is a subclass of L<KinoSearch::Search::Query> for matching
individual L<Terms|KinoSearch::Index::Term>.  Note that since Term objects are
associated with one and only one field, so are TermQueries.

=head1 METHODS

=head2 new

    my $term_query = KinoSearch::Search::TermQuery->new(
        term => $term,
    );

Constructor.  Takes hash-style parameters:

=over

=item *

B<term> - a L<KinoSearch::Index::Term>.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
