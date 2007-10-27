use strict;
use warnings;

package KinoSearch::Search::PhraseQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

our %instance_vars = (
    # inherited
    boost => 1.0,

    # params / members
    slop => 0,

    # members
    field     => undef,
    terms     => undef,
    positions => undef,
);

BEGIN {
    __PACKAGE__->ready_get_set(qw( slop ));
    __PACKAGE__->ready_get(qw( terms ));
}

use KinoSearch::Search::TermQuery;
use KinoSearch::Util::ToStringUtils qw( boost_to_string );
use KinoSearch::Util::VArray;
use KinoSearch::Util::Int;

sub init_instance {
    my $self = shift;
    $self->{terms}     = [];
    $self->{positions} = [];
}

# Add a term/position combo to the query.  The position is specified
# explicitly in order to allow for phrases with gaps, two terms at the same
# position, etc.
sub add_term {
    my ( $self, $term, $position ) = @_;
    my $field = $term->get_field;
    $self->{field} = $field unless defined $self->{field};
    confess("Mismatched fields in phrase query: '$self->{field}' '$field'")
        unless ( $field eq $self->{field} );
    if ( !defined $position ) {
        $position
            = @{ $self->{positions} }
            ? $self->{positions}[-1] + 1
            : 0;
    }
    push @{ $self->{terms} },     $term;
    push @{ $self->{positions} }, $position;
}

sub make_weight {
    my ( $self, $searcher ) = @_;

    # optimize for one-term "phrases"
    if ( @{ $self->{terms} } == 1 ) {
        my $term_query
            = KinoSearch::Search::TermQuery->new( term => $self->{terms}[0],
            );
        return $term_query->make_weight($searcher);
    }
    else {
        return KinoSearch::Search::PhraseWeight->new(
            parent   => $self,
            searcher => $searcher,
        );
    }
}

sub extract_terms { shift->{terms} }

sub to_string {
    my ( $self, $proposed_field ) = @_;
    my $string
        = $proposed_field eq $self->{field}
        ? qq(")
        : qq($proposed_field:");
    $string .= ( $_->get_text . ' ' ) for @{ $self->{terms} };
    $string .= qq(");
    $string .= qq(~$self->{slop}) if $self->{slop};
    $string .= boost_to_string( $self->get_boost );
    return $string;
}

package KinoSearch::Search::PhraseWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

our %instance_vars = (
    # inherited
    searcher   => undef,
    similarity => undef,
    parent     => undef,
);

use KinoSearch::Util::VArray;
use KinoSearch::Search::PhraseScorer;

sub init_instance {
    my $self  = shift;
    my $field = $self->{parent}{field};
    my $terms = $self->{parent}{terms};

    # don't keep searcher around; it interferes with serialization
    my $searcher = delete $self->{searcher};

    # retrieve the correct Similarity for the phrase's field
    my $sim = $self->{similarity} = $searcher->get_schema->fetch_sim($field);

    # store IDF for the phrase
    my $idf = $self->{idf} = $sim->idf( $terms, $searcher );

    # calculate raw impact
    $self->{raw_impact} = $idf * $self->{parent}->get_boost;

    # make final preparations
    $self->perform_query_normalization($searcher);
}

sub sum_of_squared_weights { shift->{raw_impact}**2 }

sub normalize {
    my ( $self, $query_norm_factor ) = @_;
    $self->{query_norm_factor} = $query_norm_factor;
    $self->{normalized_impact}
        = $self->{raw_impact} * $self->{idf} * $query_norm_factor;
}

sub get_value { shift->{normalized_impact} }

sub scorer {
    my ( $self, $reader ) = @_;
    my $query     = $self->{parent};
    my $terms     = $query->{terms};
    my $num_terms = scalar @$terms;
    my $positions = $query->{positions};

    # bail if there are no terms
    return unless $num_terms;

    # bail unless the field is valid and its posting type supports positions
    my $fspec = $reader->get_schema->fetch_fspec( $query->{field} );
    return unless defined $fspec;
    my $posting_class = $fspec->posting_type;
    return unless $posting_class->isa("KinoSearch::Posting::ScorePosting");

    # look up each term
    my $plists  = KinoSearch::Util::VArray->new( capacity => $num_terms );
    my $offsets = KinoSearch::Util::VArray->new( capacity => $num_terms );
    for my $i ( 0 .. $#$terms ) {
        my $plist = $reader->posting_list( term => $terms->[$i] );

        # bail if any one of the terms isn't in the index
        return unless defined $plist;
        return unless $plist->get_doc_freq;

        $plists->push($plist);
        $offsets->push( KinoSearch::Util::Int->new( $positions->[$i] ) );
    }

    return KinoSearch::Search::PhraseScorer->new(
        weight         => $self,
        weight_value   => $self->get_value,
        slop           => $query->{slop},
        similarity     => $self->{similarity},
        posting_lists  => $plists,
        phrase_offsets => $offsets,
    );
}

1;

__END__

=head1 NAME

KinoSearch::Search::PhraseQuery - Match ordered list of Terms.

=head1 SYNOPSIS

    my $phrase_query = KinoSearch::Search::PhraseQuery->new;
    for ( qw( the who ) ) {
        my $term = KinoSearch::Index::Term( 'bodytext', $_ );
        $phrase_query->add_term($term);
    }
    my $hits = $searcher->search( query => $phrase_query );

=head1 DESCRIPTION 

PhraseQuery is a subclass of L<KinoSearch::Search::Query> for matching against
ordered collections of terms.  

=head1 METHODS

=head2 new

    my $phrase_query = KinoSearch::Search::PhraseQuery->new;

Constructor.  Takes no arguments.

=head2 add_term

    $phrase_query->add_term($term);

Append a term to the phrase to be matched.  Takes one argument, a
L<KinoSearch::Index::Term> object.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
