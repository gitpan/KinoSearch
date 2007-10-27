use strict;
use warnings;

package KinoSearch::Search::SortSpec;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # members
    criteria => undef,
);

BEGIN { __PACKAGE__->ready_get_set(qw( criteria )) }

use KinoSearch::Search::FieldDocCollator;
use KinoSearch::Util::ByteBuf qw( bb_compare );

sub init_instance {
    my $self = shift;
    $self->{criteria} = [];
}

my %add_defaults = (
    field   => undef,
    reverse => 0,
);

sub add {
    my $self = shift;
    confess kerror() unless verify_args( \%add_defaults, @_ );
    my %criteria = ( %add_defaults, @_ );
    confess("Missing required argument 'field'")
        unless defined $criteria{field};
    push @{ $self->{criteria} }, \%criteria;
}

# Factory method returning a prepped FieldDocCollator.
sub make_field_doc_collator {
    my ( $self, $reader ) = @_;
    my $collator = KinoSearch::Search::FieldDocCollator->new;

    for my $criterion ( @{ $self->{criteria} } ) {
        my $sort_cache = $reader->fetch_sort_cache( $criterion->{field} );
        $collator->add(
            sort_cache => $sort_cache,
            reverse    => $criterion->{'reverse'},
        );
    }

    return $collator;
}

# Kludge.
sub sort_remote_docs {
    my ( $self, $docs ) = @_;

    my @reversed = map { $_->{'reverse'} } @{ $self->{criteria} };
    my $num_criteria = scalar @reversed;

    my @sorted = sort {
        my $a_field_vals = $a->get_field_vals;
        my $b_field_vals = $b->get_field_vals;
        my $comparison;
        for ( my $i = 0; $i < $num_criteria; $i++ ) {
            $comparison = bb_compare( $a_field_vals->fetch($i),
                $b_field_vals->fetch($i) );
            $comparison = 0 - $comparison if $reversed[$i];
            return $comparison if $comparison;
        }
        return $a->get_score <=> $b->get_score;
    } @$docs;
    return \@sorted;
}

1;

__END__

=head1 NAME

KinoSearch::Search::SortSpec - Specify a custom sort order for search results.

=head1 SYNOPSIS

    my $sort_spec = KinoSearch::Search::SortSpec->new;
    $sort_spec->add( field => 'date' );
    my $hits = $searcher->search(
        query     => $query,
        sort_spec => $sort_spec,
    );

=head1 DESCRIPTION

By default, searches return results in order of relevance. SortSpec allows you
to indicate an alternate order, using the contents of one or more fields.

Fields you wish to sort against must be indexed but must I<not> be analyzed,
as each document needs to be associated with a single value.

=head2 Memory and Caching

Each field that you sort against requires a sort cache, which is a C array of
32-bit integers.  For each cache, the memory requirements are 4 bytes for each
document in the index, plus loose change for object overhead.  Additionally, a
cache comprising some fraction of the terms in the index must be loaded.  The
time it takes to warm these caches on the first sorted search can be
noticeable, but if you reuse your Searcher subsequent searches should be
faster.

=head1 METHODS

=head2 new

    my $sort_spec = KinoSearch::Search::SortSpec->new;

Constructor.  Takes no arguments.

=head2 add

    $sort_spec->add( 
        field   => $field_name,   # required
        reverse => 1,             # default: 0
    );

Add a field to sort against.  Multiple sort criteria are processed in the
order they were added (so the first to be added is the most important).  Takes
labeled parameters.

=over

=item *

B<field> - The name of a field which is indexed but not analyzed.

=item *

B<reverse> - Reverse the order of the sort for this particular field.

=back

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
