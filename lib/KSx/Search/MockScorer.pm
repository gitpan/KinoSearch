use strict;
use warnings;

package KSx::Search::MockScorer;
BEGIN { our @ISA = qw( KinoSearch::Search::Matcher ) }
use Carp;
use Scalar::Util qw( reftype );

# Inside-out member vars.
our %doc_ids;
our %scores;
our %tick;

sub new {
    my ( $either, %args ) = @_;
    for (qw( doc_ids scores )) {
        confess("Required parameter $_ isn't an array")
            unless reftype( $args{$_} ) eq 'ARRAY';
    }
    my $doc_ids = delete $args{doc_ids};
    my $scores  = delete $args{scores};
    my $self    = $either->SUPER::new(%args);
    $doc_ids{$$self} = $doc_ids;
    $scores{$$self}  = $scores;
    $tick{$$self}    = -1;
    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $doc_ids{$$self};
    delete $scores{$$self};
    delete $tick{$$self};
    $self->SUPER::DESTROY;
}

sub get_doc_id {
    my $self = shift;
    return $doc_ids{$$self}->[ $tick{$$self} ];
}

sub next {
    my $self = shift;
    my $tick = ++$tick{$$self};
    my $docs = $doc_ids{$$self};
    return 0 if $tick > $#$docs;
    return $self->get_doc_id;
}

sub score {
    my $self = shift;
    return $scores{$$self}->[ $tick{$$self} ];
}

sub reset {
    my $self = shift;
    $tick{$$self} = -1;
}

1;

__END__

__POD__

=head1 NAME

KSx::Search::MockScorer - Matcher with arbitrary docs and scores.

=head1 DESCRIPTION 

Used for testing combining scorers such as ANDScorer, MockScorer allows
arbitrary match criteria to be supplied, obviating the need for clever index
construction to cover corner cases.

MockScorer is a testing and demonstration class; it is unsupported.

=head1 CONSTRUCTORS

=head2 new( [I<labeled params>] )

=over

=item *

B<doc_ids> - A sorted array of L<doc_ids|KinoSearch::Docs::DocIDs>.

=item *

B<scores> - An array of scores, one for each doc_id.

=back

=head1 COPYRIGHT

Copyright 2007-2010 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
