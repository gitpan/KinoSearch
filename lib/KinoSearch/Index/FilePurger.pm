use KinoSearch;

1;

__END__

__BINDING__

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::FilePurger",
    bind_methods      => [qw( Purge )],
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2007-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
