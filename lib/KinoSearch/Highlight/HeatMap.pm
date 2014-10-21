use KinoSearch;

1;

__END__

__BINDING__

my $constructor = <<'END_CONSTRUCTOR';
    my $heat_map = KinoSearch::Highlight::HeatMap->new(
        spans  => \@highlight_spans,
        window => 100,
    );
END_CONSTRUCTOR

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Highlight::HeatMap",
    bind_methods => [
        qw(
            Calc_Proximity_Boost
            Generate_Proximity_Boosts
            Flatten_Spans
            )
    ],
    bind_constructors => ["new"],
    make_pod          => {
        synopsis    => "    # TODO.\n",
        constructor => { sample => $constructor },
    },
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

