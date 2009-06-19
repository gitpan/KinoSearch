use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Search::PolyQuery" => {
        bind_methods      => [qw( Add_Child Set_Children Get_Children )],
        make_constructors => ["new"],
        make_pod          => { }
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

