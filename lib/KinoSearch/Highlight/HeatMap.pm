use KinoSearch;

1;

__END__

__AUTO_XS__

my $constructor = <<'END_CONSTRUCTOR';
    my $heat_map = KinoSearch::Highlight::HeatMap->new(
        spans  => \@highlight_spans,
        window => 100,
    );
END_CONSTRUCTOR

{   "KinoSearch::Highlight::HeatMap" => {
        bind_methods => [
            qw(
                Calc_Proximity_Boost
                Generate_Proximity_Boosts
                Flatten_Spans
                )
        ],
        make_getters      => [qw( spans window )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => "    # TODO.\n",
            constructor => { sample => $constructor },
        },
    }
}
