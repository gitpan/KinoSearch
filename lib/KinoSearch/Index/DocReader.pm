use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $doc_reader = $seg_reader->obtain("KinoSearch::Index::DocReader");
    my $doc        = $doc_reader->fetch($doc_id);
END_SYNOPSIS

{   "KinoSearch::Index::DocReader" => {
        make_constructors => ["new"],
        bind_methods      => [qw( Fetch )],
        make_pod          => {
            synopsis => $synopsis,
            methods  => [qw( fetch aggregator )],
        },
    },
    "KinoSearch::Index::DefaultDocReader" => { 
        make_constructors => ["new"], 
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
