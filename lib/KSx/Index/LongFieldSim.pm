use strict;
use warnings;

package KSx::Index::LongFieldSim;
use base qw( KinoSearch::Index::Similarity );

sub length_norm {
    my ( $self, $num_tokens ) = @_;
    $num_tokens = $num_tokens < 100 ? 100 : $num_tokens;
    return 1 / sqrt($num_tokens);
}

1;

__END__

__POD__

=head1 NAME

KSx::Index::LongFieldSim - Similarity optimized for long fields.

=head1 SYNOPSIS

    package MySchema::body;
    use base qw( KinoSearch::Plan::FullTextType );
    use KSx::Index::LongFieldSim;
    sub make_similarity { KSx::Index::LongFieldSim->new }

=head1 DESCRIPTION

KinoSearch's default L<Similarity|KinoSearch::Index::Similarity>
implmentation produces a bias towards extremely short fields.

    KinoSearch::Index::Similarity
    
    | more weight
    | *
    |  **  
    |    ***
    |       **********
    |                 ********************
    |                                     *******************************
    | less weight                                                        ****
    |------------------------------------------------------------------------
      fewer tokens                                              more tokens

LongFieldSim eliminates this bias.

    KSx::Index::LongFieldSim
    
    | more weight
    | 
    |    
    |    
    |*****************
    |                 ********************
    |                                     *******************************
    | less weight                                                        ****
    |------------------------------------------------------------------------
      fewer tokens                                              more tokens

In most cases, the default bias towards short fields is desirable.  For
instance, say you have two documents:

=over

=item *

"George Washington"

=item *

"George Washington Carver"

=back

If a user searches for "george washington", we want the exact title match to
appear first.  Under the default Similarity implementation it will, because
the "Carver" in "George Washington Carver" dilutes the impact of the other two
tokens.  

However, under LongFieldSim, the two titles will yield equal scores.  That
would be bad in this particular case, but it could be good in another.  

     "George Washington Carver is cool."

     "George Washington Carver was born on the eve of the US Civil War, in
     1864.  His exact date of birth is unknown... Carver's research in crop
     rotation revolutionized agriculture..."

The first document is succinct, but useless.  Unfortunately, the default
similarity will assess it as extremely relevant to a query of "george
washington carver".  However, under LongFieldSim, the short-field bias is
eliminated, and the addition of other mentions of Carver's name in the second
document yield a higher score and a higher rank.

=head1 COPYRIGHT

Copyright 2005-2010 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut


