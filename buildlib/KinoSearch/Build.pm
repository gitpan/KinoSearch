use strict;
use warnings;

package KinoSearch::Build;
use base qw( Lucy::Build );

BEGIN { Lucy::Build->use_kinosearch_mode }

1;

__END__

=head1 NAME

KinoSearch::Build -- Module::Build subclass for KinoSearch

=head1 SYNOPSIS

    my $builder = KinoSearch::Build->new(
        %args_to_module_build_constructor;
    );
    $builder->create_build_script;

=head1 DESCRIPTION

KinoSearch stores XS code inside .pm files (see L<KinoSearch::Docs::DevGuide>
for the reasoning behind that strategy) and auto-generates a bunch of C code
using devel/boilerplater.pl.  This custom Module::Build subclass does some
extra work extracting and writing those files on the fly.

=head1 COPYRIGHT

Copyright 2005-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch>.

=cut
