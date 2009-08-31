use KinoSearch;

1;

__END__

__BINDING__

my $synopsis = <<'END_SYNOPSIS';
    my $schema       = KinoSearch::Schema->new;
    my $float64_type = KinoSearch::FieldType::FloatType->new;
    $schema->spec_field( name => 'intensity', type => $float64_type );
END_SYNOPSIS
my $constructor = <<'END_CONSTRUCTOR';
    my $float64_type = KinoSearch::FieldType::Float64Type->new(
        indexed  => 0     # default true
        stored   => 0,    # default true
        sortable => 1,    # default false
    );
END_CONSTRUCTOR

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::FieldType::Float64Type",
    bind_constructors => ["new|init2"],
    #make_pod          => {
    #    synopsis    => $synopsis,
    #    constructor => { sample => $constructor },
    #},
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

