use strict;
use warnings;

package KinoSearch::Search::MatchFieldQuery;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Query );

our %instance_vars = (
    # params / members
    field => undef,
    boost => 0.0,
);

use KinoSearch::Schema;

sub make_weight {
    my ( $self, $searcher ) = @_;
    my $weight = KinoSearch::Search::MatchFieldWeight->new(
        parent   => $self,
        searcher => $searcher,
    );
}

sub extract_terms { }

package KinoSearch::Search::MatchFieldWeight;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Search::Weight );

use KinoSearch::Search::MatchFieldScorer;

our %instance_vars = (
    # inherited
    searcher   => undef,
    parent     => undef,
    similarity => undef,

    # members
    raw_impact        => undef,
    query_norm_factor => undef,
    impact            => undef,
);

sub init_instance {
    my $self  = shift;
    my $field = $self->{parent}{field};

    # don't keep searcher around; it interferes with serialization
    my $searcher = delete $self->{searcher};

    # retrieve the correct Similarity for this field
    $self->{similarity} = $searcher->get_schema->fetch_sim($field);

    # store a non-normalized weighting factor
    $self->{raw_impact} = $self->{parent}->get_boost;

    # make final preparations
    $self->perform_query_normalization($searcher);
}

sub sum_of_squared_weights {
    my $self = shift;
    return $self->{raw_impact}**2;
}

sub normalize {
    my ( $self, $query_norm_factor ) = @_;
    $self->{query_norm_factor} = $query_norm_factor;
    $self->{impact}            = $self->{raw_impact} * $query_norm_factor;
}

sub get_value { shift->{impact} }

sub scorer {
    my ( $self, $reader ) = @_;
    my $field = $self->{parent}{field};

    # bail if the field isn't a sort field
    my $invindex   = $reader->get_invindex;
    my $field_spec = $invindex->get_schema->fetch_fspec($field);
    return
        unless ( defined $field_spec
        and $field_spec->indexed
        and !$field_spec->analyzed );

    return KinoSearch::Search::MatchFieldScorer->new(
        similarity => $self->{similarity},
        weight     => $self,
        sort_cache => $reader->fetch_sort_cache($field),
    );
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Search::MatchFieldQuery - Match a field.

=head1 DESCRIPTION 

MatchFieldQuery matches all documents that have a value for a given field --
even if that value is an empty string.

The present implementation contributes nothing to the score; it only matches.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
