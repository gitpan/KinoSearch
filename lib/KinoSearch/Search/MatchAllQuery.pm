use KinoSearch;

1;

__END__

__AUTO_XS__


my $constructor = <<'END_CONSTRUCTOR';
    my $match_all_query = KinoSearch::Search::MatchAllQuery->new;
END_CONSTRUCTOR

{   "KinoSearch::Search::MatchAllQuery" => {
        make_constructors => ["new"],
                make_pod => {
            constructor => { sample => $constructor },
        }
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

