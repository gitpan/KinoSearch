use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::DeletionsReader" => {
        make_constructors => ['new'],
        bind_methods => [qw( Iterator Del_Count )],
    },
    "KinoSearch::Index::DefaultDeletionsReader" => {
        make_constructors => ['new'],
        bind_methods      => [qw( Read_Deletions )],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
