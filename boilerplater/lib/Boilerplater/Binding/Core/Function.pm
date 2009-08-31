use strict;
use warnings;

package Boilerplater::Binding::Core::Function;
use Boilerplater::Util qw( a_isa_b );

# Return the function's C declaration.
sub func_declaration {
    my ( undef, $function ) = @_;
    confess("Not a Function")
        unless a_isa_b( $function, "Boilerplater::Function" );
    my $return_type = $function->get_return_type;
    my $param_list  = $function->get_param_list;
    my $dec = $function->inline ? 'static CHY_INLINE ' : '';
    $dec .= $return_type->to_c . "\n";
    $dec .= $function->full_func_sym;
    $dec .= "(" . $param_list->to_c . ");";
    return $dec;
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Binding::Core::Function - Generate core C code for a function.

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
