package KinoSearch::Util::Stepper;
use KinoSearch;

1;

__END__

__BINDING__

Clownfish::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Util::Stepper",
    bind_methods => [qw( Read_Record )],
);

__COPYRIGHT__

Copyright 2005-2011 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

