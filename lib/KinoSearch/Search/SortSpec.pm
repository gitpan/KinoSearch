use KinoSearch;

1;

__END__


__AUTO_XS__


my $synopsis = <<'END_SYNOPSIS';
    my $sort_spec = KinoSearch::Search::SortSpec->new(
        rules => [
            KinoSearch::Search::SortRule->new( field => 'date' ),
            KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
        ],
    );
    my $hits = $searcher->hits(
        query     => $query,
        sort_spec => $sort_spec,
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $sort_spec = KinoSearch::Search::SortSpec->new( rules => \@rules );
END_CONSTRUCTOR

{   "KinoSearch::Search::SortSpec" => {
        bind_methods      => [qw( Get_Rules )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

