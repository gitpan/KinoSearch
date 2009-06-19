use KinoSearch;

1;

__END__

__AUTO_XS__

my $constructor = <<'END_CONSTRUCTOR';
    package MyHitCollector;
    use base qw( KinoSearch::Search::HitCollector );
    our %foo;
    sub new {
        my $self = shift->SUPER::new;
        my %args = @_;
        $foo{$$self} = $args{foo};
        return $self;
    }
END_CONSTRUCTOR

{   "KinoSearch::Search::HitCollector" => {
        bind_methods => [
            qw(
                Collect
                Set_Reader
                Set_Base
                Set_Matcher
                Need_Score
                )
        ],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => "    # Abstract base class.\n",
            constructor => { sample => $constructor },
            methods     => [qw( collect )],
        },
    },
    "KinoSearch::Search::HitCollector::OffsetCollector" =>
        { make_constructors => ["new"], },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

