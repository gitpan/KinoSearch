package KinoSearch::Index::FilePurger;
use KinoSearch;

1;

__END__

__BINDING__

Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::FilePurger",
    bind_methods      => [qw( Purge )],
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2007-2011 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
