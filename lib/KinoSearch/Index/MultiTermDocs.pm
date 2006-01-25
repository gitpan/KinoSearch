package KinoSearch::Index::MultiTermDocs;
use strict;
use warnings;

=for comment

This module is NOT DONE.

=cut

use base qw( KinoSearch::Index::TermDocs );
use Scalar::Util qw( blessed );

use Clone qw( clone );

our %instance_vars = (
    %KinoSearch::Index::TermDocs,
    readers => [],
    starts  => [],

    pointer => 0,

    reader_term_docs => [],
    current          => undef,
);

sub init_instance {
    my $self = shift;

    %$self = ( %$self, @_ );
    for my $i ( 0 .. $#{ $self->{readers} } ) {
        my $seg_reader   = $self->{readers}[$i];
        my $start_offset = $self->{starts}[$i];
        push @{ $self->{reader_term_docs} },
            KinoSearch::Index::SegmentTermDocs->new(
            seg_reader   => $seg_reader,
            start_offset => $start_offset,
            );
    }
    $self->{current} = $self->{seg_term_docs}[0];
}

sub seek {
    my ( $self, $thing ) = @_;
    $self->{termstring} = $thing;
    if ( blessed($thing) and $thing->isa('KinoSearch::Index::TermEnum') ) {
        $self->{termstring} = $thing->get_term;
    }
    $self->{pointer} = 0;
    $self->{current} = undef;
}

sub read {
    my $self        = $_[0];
    my $num_to_read = $_[3];

    while (1) {
        while ( !defined $self->{current} ) {
            # try next segment
            if ( $self->{pointer} < @{ $self->{seg_term_docs} } ) {
                $self->{current} = $self->{seg_term_docs}[ $self->{pointer} ];
                $self->{pointer}++;
            }
            else {
                return 0;
            }
        }
        my $end = $self->{current}->read( $_[1], $_[2], $num_to_read );
        if ( $end == 0 ) {
            $self->{current} = undef;
        }
        else {
            return $end;
        }

    }
}

sub close {
    my $self = shift;
    for ( @{ $self->{reader_term_docs} } ) {
        $_->close if defined $_;
    }
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Index::MultiTermDocs - multi-segment TermDocs

=head1 DESCRIPTION 

This module is NOT DONE.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=end devdocs
=cut
