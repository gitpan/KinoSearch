use strict;
use warnings;

package Boilerplater::DocuComment;
use Carp;

sub new {
    my ( $either, $text ) = @_;

    my ( @param_names, @param_docs );
    my $self = bless {
        brief       => undef,
        full        => undef,
        param_names => \@param_names,
        param_docs  => \@param_docs,
        retval      => undef,
        },
        ref($either) || $either;

    # Strip comment open, close, and left border.
    $text =~ s/\A\s*\/\*\*\s+//;
    $text =~ s/\s+\*\/\s*\Z//;
    $text =~ s/^\s*\* ?//gm;

    # Extract the brief description.
    $text =~ /^(.+?\.)(\s+|\Z)/s
        or confess("Can't find at least one descriptive sentence in '$text'");
    $self->{brief} = $1;

    # terminated by @, empty line, or string end.
    my $terminator = qr/((?=\@)|\n\s*\n|\Z)/;

    # Extract @param, @return directives.
    while (
        $text =~ s/^\s*
        \@param\s+
        (\w+)   # param name
        \s+
        (.*?)   # param description
        \s*
        $terminator
      //xsm
        )
    {
        push @param_names, $1;
        push @param_docs,  $2;
    }
    if ( $text =~ s/^\s*\@return\s+(.*?)$terminator//sm ) {
        $self->{retval} = $1;
    }

    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $self->{full} = $text;

    $text =~ s/^(.+?\.)(\s+|\Z)//s;    # zap brief
    $text =~ s/^\s*//;
    $self->{description} = $text;

    return $self;
}

sub get_param_names { shift->{param_names} }
sub get_param_docs  { shift->{param_docs} }
sub get_retval      { shift->{retval} }
sub get_brief       { shift->{brief} }
sub get_full        { shift->{full} }
sub get_description { shift->{description} }

1;

__END__

__POD__

=head1 NAME

Boilerplater::DocuComment - Formatted comment a la Doxygen.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
