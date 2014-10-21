use KinoSearch;

1;

__END__

__BINDING__

my $constructor = <<'END_CONSTRUCTOR';
    my $match_all_query = KinoSearch::Search::MatchAllQuery->new;
END_CONSTRUCTOR

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Search::MatchAllQuery",
    bind_constructors => ["new"],
    make_pod          => { constructor => { sample => $constructor }, }
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

