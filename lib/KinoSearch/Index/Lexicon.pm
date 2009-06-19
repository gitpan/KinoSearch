use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $lexicon = $index_reader->lexicon( field => 'content' );
    while ( $lexicon->next ) {
       print $lexicon->get_term . "\n";
    }
END_SYNOPSIS

{   "KinoSearch::Index::Lexicon" => {
        bind_methods      => [qw( Seek Next Reset Get_Term )],
        make_getters      => [qw( field )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis => $synopsis,
            methods  => [qw( seek next get_term reset )],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

