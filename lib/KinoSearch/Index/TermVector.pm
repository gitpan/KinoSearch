package KinoSearch::Index::TermVector;
use KinoSearch;

1;

__END__

__BINDING__

Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::TermVector",
    bind_constructors => ["new"],
    bind_methods      => [
        qw(
            Get_Positions
            Get_Start_Offsets
            Get_End_Offsets
            )
    ],
);

__COPYRIGHT__

Copyright 2005-2011 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.



