use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::TermVector" => {
        make_constructors => ["new"],
        bind_methods      => [qw( Get_Positions Get_Start_Offsets Get_End_Offsets )],
        make_getters      => [qw( text field )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.



