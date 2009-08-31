use KinoSearch;

1;

__END__

__BINDING__

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Analysis::Analyzer",
    bind_methods      => [qw( Transform Transform_Text Split )],
    bind_constructors => ["new"],
    make_pod          => { synopsis => "    # Abstract base class.\n", }
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

