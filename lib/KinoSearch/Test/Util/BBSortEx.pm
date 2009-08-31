use KinoSearch;

1;

__END__

__BINDING__

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Test::Util::BBSortEx",
    bind_constructors => ["new"],
);
Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Test::Util::BBSortExRun",
    bind_constructors => ["new"],
    bind_methods      => [qw( Set_Mem_Thresh )],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

