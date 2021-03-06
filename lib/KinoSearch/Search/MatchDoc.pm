package KinoSearch::Search::MatchDoc;
use KinoSearch;

1;

__END__

__BINDING__

Clownfish::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Search::MatchDoc",
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
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2005-2011 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

