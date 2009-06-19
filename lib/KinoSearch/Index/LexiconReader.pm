use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $lex_reader = $seg_reader->obtain("KinoSearch::Index::LexiconReader");
    my $lexicon    = $lex_reader->lexicon( field => 'title' );
END_SYNOPSIS

{   "KinoSearch::Index::LexiconReader" => {
        bind_methods      => [qw( Lexicon Doc_Freq Fetch_Term_Info )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis => $synopsis,
            methods  => [qw( lexicon doc_freq )],
        },
    },
    "KinoSearch::Index::DefaultLexiconReader" => {
        make_constructors => ["new"],
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

