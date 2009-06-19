use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::TermInfo" => {
        bind_methods      => [qw( Reset )],
        make_constructors => ["new"],
        make_getters =>
            [qw( doc_freq post_filepos skip_filepos lex_filepos )],
        make_setters =>
            [qw( doc_freq post_filepos skip_filepos lex_filepos )],
    }
}

__COPYRIGHT__

Copyright 2006-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

