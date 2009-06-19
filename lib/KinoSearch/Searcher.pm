use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $searcher = KinoSearch::Searcher->new( index => '/path/to/index' );
    my $hits = $searcher->hits(
        query      => 'foo bar',
        offset     => 0,
        num_wanted => 100,
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $searcher = KinoSearch::Searcher->new( index => '/path/to/index' );
END_CONSTRUCTOR

{   "KinoSearch::Searcher" => {
        bind_methods      => [qw( Get_Reader )],
        make_constructors => ["new"],
        make_pod => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods => [
                qw( hits 
                    collect
                    doc_max
                    doc_freq
                    fetch_doc
                    get_schema 
                    get_reader )
            ],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

