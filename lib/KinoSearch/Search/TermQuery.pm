package KinoSearch::Search::TermQuery;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

use KinoSearch::Util::ToStringUtils qw( boost_to_string );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        term => undef,
    );
    __PACKAGE__->ready_get(qw( term ));
}

sub init_instance {
    my $self = shift;
    confess("parameter 'term' is not a KinoSearch::Index::Term")
        unless a_isa_b( $self->{term}, 'KinoSearch::Index::Term' );
}

sub create_weight {
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

sub get_similarity {
	my ( $self, $searcher ) = @_;
	my $field_name = $self->{term}->get_field;
	return $searcher->get_similarity($field_name);
}

sub equals { shift->todo_death }

package KinoSearch::Search::TermWeight;
use strict;
use warnings;
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
    return unless $term_docs->get_doc_freq;

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

=head1 NAME

KinoSearch::Search::TermQuery - match individual Terms

=head1 SYNOPSIS

    my $term = KinoSearch::Index::Term->new( $field, $term_text );
    my $term_query = KinoSearch::Search::TermQuery->new(
        term => $term,
    );
    my $hits = $searcher->search( query => $term_query );

=head1 DESCRIPTION 

TermQuery is a subclass of
L<KinoSearch::Search::Query|KinoSearch::Search::Query> for matching individual
L<Terms|KinoSearch::Index::Term>.  Note that since Term objects are associated
with one and only one field, so are TermQueries.

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

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.12.

=cut

