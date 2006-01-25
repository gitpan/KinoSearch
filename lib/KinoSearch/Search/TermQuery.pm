package KinoSearch::Search::TermQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

use KinoSearch::Util::ToStringUtils qw( boost_to_string );

our %instance_vars = __PACKAGE__->init_instance_vars( term => undef );

sub init_instance {
    my $self = shift;
    confess("parameter 'term' is not a KinoSearch::Index::Term")
        unless a_isa_b( $self->{term}, 'KinoSearch::Index::Term' );
}

sub get_term { shift->{term} }

sub create_weight {
    my ( $self, $searcher ) = @_;
    my $weight = KinoSearch::Search::TermWeight->new(
        parent   => $self,
        searcher => $searcher,
    );
}

sub extract_terms { shift->todo_death }

sub to_string {
    my ( $self, $proposed_field ) = @_;
    my $field = $self->{term}->get_field;
    my $string = $proposed_field eq $field ? '' : "$field:";
    $string .= $self->{term}->get_text . boost_to_string( $self->{boost} );
    return $string;

}

sub equals { shift->todo_death }

package KinoSearch::Search::TermWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

use KinoSearch::Search::TermScorer;

our %instance_vars = __PACKAGE__->init_instance_vars();

sub init_instance {
    my $self = shift;

    $self->{similarity}
        = $self->{parent}->get_similarity( $self->{searcher} );

    $self->{idf} = $self->{similarity}
        ->idf( $self->{parent}->get_term, $self->{searcher} );
}

sub scorer {
    my ( $self, $reader ) = @_;
    my $term      = $self->{parent}{term};
    my $term_docs = $reader->term_docs($term);
    return unless defined $term_docs;

    my $norms_reader = $reader->norms_reader( $term->get_field );
    return KinoSearch::Search::TermScorer->new(
        weight       => $self,
        term_docs    => $term_docs,
        similarity   => $self->{similarity},
        norms_reader => $norms_reader,
    );
}

sub to_string {
    my $self = shift;
    return "weight(" . $self->{parent}->to_string . ")";
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::TermQuery - match individual Terms

=head1 DESCRIPTION 

Subclass of Query for matching individual Terms.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=end devdocs
=cut

