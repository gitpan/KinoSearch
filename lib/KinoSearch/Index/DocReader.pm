package KinoSearch::Index::DocReader;
use KinoSearch;

1;

__END__

__BINDING__

my $synopsis = <<'END_SYNOPSIS';
    my $doc_reader = $seg_reader->obtain("KinoSearch::Index::DocReader");
    my $doc        = $doc_reader->fetch_doc($doc_id);
END_SYNOPSIS

Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::DocReader",
    bind_constructors => ["new"],
    bind_methods      => [qw( Fetch_Doc )],
    make_pod          => {
        synopsis => $synopsis,
        methods  => [qw( fetch_doc aggregator )],
    },
);
Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::DefaultDocReader",
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2005-2011 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
