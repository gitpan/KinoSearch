use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::DocVector" => {
        bind_methods =>
            [ qw( Term_Vector Field_Buf Add_Field_Buf ) ],
        make_constructors => ["new"],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.


