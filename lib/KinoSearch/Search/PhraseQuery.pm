package KinoSearch::Search::PhraseQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

use KinoSearch::Search::TermQuery;
use KinoSearch::Document::Field;
use KinoSearch::Util::ToStringUtils qw( boost_to_string );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor args / members
    slop => 0,
    # members
    field     => undef,
    terms     => [],
    positions => [],
);
__PACKAGE__->ready_get_set(qw( slop ));
__PACKAGE__->ready_get(qw( terms ));

# Add a term/position combo to the query.  The position is specified
# explicitly in order to allow for phrases with gaps, two terms at the same
# position, etc.
sub add_term {
    my ( $self, $term, $position ) = @_;
    my $field = $term->get_field;
    $self->{field} = $field unless defined $self->{field};
    croak("Mismatched fields in phrase query: '$self->{field}' '$field'")
        unless ( $field eq $self->{field} );
    if ( !defined $position ) {
        $position =
            @{ $self->{positions} }
            ? $self->{positions}[-1] + 1
            : 0;
    }
    push @{ $self->{terms} },     $term;
    push @{ $self->{positions} }, $position;
}

sub create_weight {
    my ( $self, $searcher ) = @_;

    # optimize for one-term phrases
    if ( @{ $self->{terms} } == 1 ) {
        my $term_query
            = KinoSearch::Search::TermQuery->new( term => $self->{terms}[0],
            );
        return $term_query->create_weight($searcher);
    }
    else {
        return KinoSearch::Search::PhraseWeight->new(
            parent   => $self,
            searcher => $searcher,
        );
    }
}

sub extract_terms { shift->todo_death }

sub to_string {
    my ( $self, $proposed_field ) = @_;
    my $string =
        $proposed_field eq $self->{field}
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

use KinoSearch::Search::PhraseScorer;

our %instance_vars = __PACKAGE__->init_instance_vars();

sub init_instance {
    my $self = shift;
    $self->{similarity}
        = $self->{parent}->get_similarity( $self->{searcher} );
    $self->{idf} = $self->{similarity}
        ->idf( $self->{parent}->get_terms, $self->{searcher} );
}

sub scorer {
    my ( $self, $reader ) = @_;
    my $query = $self->{parent};

    # look up each term
    my @term_docs;
    for my $term ( @{ $query->{terms} } ) {
        my $td = $reader->term_docs($term);

        # bail if any one of the terms isn't in the index
        return unless defined $td;
        push @term_docs, $td;

        # turn on positions
        $td->set_read_positions(1);
    }

    # bail if there are no terms
    return unless @term_docs;

    return KinoSearch::Search::PhraseScorer->new(
        weight          => $self,
        slop            => $query->{slop},
        similarity      => $self->{similarity},
        norms_reader    => $reader->norms_reader( $query->{field} ),
        term_docs       => \@term_docs,
        phrase_offsets  => $query->{positions},
    );
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::PhraseQuery - match ordered list of Terms

=head1 DESCRIPTION 

Subclass of Query for collections of ordered terms.  

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut

