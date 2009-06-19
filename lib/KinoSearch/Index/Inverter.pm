use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::Inverter" => {
        make_constructors => ["new"],
        bind_methods => [qw(
            Get_Doc
            Iter_Init
            Next
            Clear
            Get_Field_Name
            Get_Value
            Get_Type
            Get_Analyzer
            Get_Similarity
            Get_Inversion
        )],
        make_getters => [qw( schema )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

