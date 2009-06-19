use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::SegPostingList" => {
        bind_methods      => [qw( Set_Doc_Base )],
        make_getters      => [qw( post_stream count )], # testing only
        make_constructors => ["new"],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

