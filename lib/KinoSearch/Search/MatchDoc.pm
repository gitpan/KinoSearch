use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Search::MatchDoc" => {
        bind_methods => [
            qw(
                Get_Doc_ID
                Set_Doc_ID
                Get_Score
                Set_Score
                Get_Values
                Set_Values
                )
        ],
        make_constructors => ["new"],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

