use strict;
use warnings;

package KinoSearch::Test::Util::TestCharBuf;
use KinoSearch::Util::ToolSet qw( to_perl );
BEGIN {
    push our @ISA, 'Exporter';
    our @EXPORT_OK = qw( vcatf_tests );
}

sub vcatf_tests { to_perl( _vcatf_tests() ) }

1;

__END__

__AUTO_XS__

{   "KinoSearch::Test::Util::TestCharBuf" => {
        bind_methods => [
            qw( Get_Wanted
                Get_Got )
        ],
    }
}

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Test::Util::TestCharBuf

SV*
_vcatf_tests()
CODE:
    KOBJ_TO_SV_NOINC( kino_TestCB_vcatf_tests(), RETVAL );
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

