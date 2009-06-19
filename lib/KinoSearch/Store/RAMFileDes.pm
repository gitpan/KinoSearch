use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Store::RAMFileDes" => {
        bind_methods      => [qw( Contents )],
        make_constructors => ['new'],
        make_getters      => [qw( len )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

