use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $schema     = KinoSearch::Schema->new;
    my $int64_type = KinoSearch::FieldType::Int64Type->new;
    $schema->spec_field( name => 'count', type => $int64_type );
END_SYNOPSIS
my $constructor = <<'END_CONSTRUCTOR';
    my $int64_type = KinoSearch::FieldType::Int64Type->new(
        indexed  => 0,    # default true
        stored   => 0,    # default true
        sortable => 1,    # default false
    );
END_CONSTRUCTOR

{   "KinoSearch::FieldType::Int64Type" => {
        make_constructors => ["new|init2"],
        #make_pod          => {
        #    synopsis    => $synopsis,
        #    constructor => { sample => $constructor },
        #},
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

