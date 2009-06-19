use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $phrase_query = KinoSearch::Search::PhraseQuery->new( 
        field => 'content',
        terms => [qw( the who )],
    );
    my $hits = $searcher->hits( query => $phrase_query );
END_SYNOPSIS

{   "KinoSearch::Search::PhraseQuery" => {
        bind_methods      => [qw( Get_Field Get_Terms )],
        make_constructors => ["new"],
        make_pod          => {
            constructor => { sample => '' },
            synopsis => $synopsis,
            methods => [qw( get_field get_terms )],
        },
    },
    "KinoSearch::Search::PhraseCompiler" =>
        { make_constructors => ["do_new"], },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

