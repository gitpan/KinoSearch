use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $string_type = KinoSearch::FieldType::StringType->new;
    my $blob_type   = KinoSearch::FieldType::BlobType->new;
    my $schema      = KinoSearch::Schema->new;
    $schema->spec_field( name => 'id',   type => $string_type );
    $schema->spec_field( name => 'jpeg', type => $blob_type );
END_SYNOPSIS
my $constructor = <<'END_CONSTRUCTOR';
    my $blob_type = KinoSearch::FieldType::BlobType->new;
END_CONSTRUCTOR

{   "KinoSearch::FieldType::BlobType" => {
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

