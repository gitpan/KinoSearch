use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $type   = KinoSearch::FieldType::StringType->new;
    my $schema = KinoSearch::Schema->new;
    $schema->spec_field( name => 'category', type => $type );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $type = KinoSearch::FieldType::StringType->new(
        boost    => 0.1,    # default: 1.0
        indexed  => 1,      # default: true
        stored   => 1,      # default: true
        sortable => 1,      # default: false
    );
END_CONSTRUCTOR

{   "KinoSearch::FieldType::StringType" => {
        make_constructors => ["new|init2"],
        make_pod => {
            synopsis => $synopsis,
            constructor => { sample => $constructor },
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

