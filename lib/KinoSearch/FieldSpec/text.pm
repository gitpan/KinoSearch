use strict;
use warnings;

package KinoSearch::FieldSpec::text;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::FieldSpec );
use KinoSearch::Posting::ScorePosting;
use KinoSearch::Search::Similarity;

use constant TRUE  => 1;
use constant FALSE => 0;

sub indexed    {TRUE}
sub stored     {TRUE}
sub analyzed   {TRUE}
sub vectorized {TRUE}
sub binary     {FALSE}
sub compressed {FALSE}

1;

__END__

__POD__

=head1 NAME 

KinoSearch::FieldSpec::text - Default behaviors for text fields

=head1 SYNOPSIS

Arrange for your subclass of KinoSearch::Schema to load
KinoSearch::FieldSpec::text via its alias, 'text'...

    package MySchema;
    use base qw( KinoSearch::Schema );

    our %fields = (
        title   => 'text',   # alias for KinoSearch::FieldSpec::text
        content => 'text',
    );

... or define a custom subclass and use it instead:

    package MySchema::UnAnalyzed;
    use base qw( KinoSearch::FieldSpec::text )
    sub analyzed { 0 }
    
    package MySchema;
    use base qw( KinoSearch::Schema );
    
    our %fields = (
        title => 'text',
        url   => 'MySchema::UnAnalyzed',
    );

=head1 DESCRIPTION

KinoSearch::FieldSpec::text is an implementation of L<KinoSearch::FieldSpec>
tuned for ease of use with text fields.  It has the following properties:

    indexed      TRUE
    stored       TRUE
    analyzed     TRUE
    vectorized   TRUE
    binary       FALSE
    compressed   FALSE

Its common to use this class as a base class and override one or more of
those values.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
