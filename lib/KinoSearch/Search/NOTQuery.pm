use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $not_bar_query = KinoSearch::Search::NOTQuery->new( 
        negated_query => $bar_query,
    );
    my $foo_and_not_bar_query = KinoSearch::Search::ANDQuery->new;
    $foo_and_not_bar_query->add_child($foo_query);
    $foo_and_not_bar_query->add_child($not_bar_query);
    my $hits = $searcher->hits( query => $foo_and_not_bar_query );
    ...
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $not_query = KinoSearch::Search::NOTQuery->new( 
        negated_query => $query,
    );
END_CONSTRUCTOR

{   "KinoSearch::Search::NOTQuery" => {
        make_constructors => ["new"],
        bind_methods => [qw( Get_Negated_Query Set_Negated_Query )],
        make_pod          => {
            methods => [ qw( get_negated_query set_negated_query ) ],
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        }
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

