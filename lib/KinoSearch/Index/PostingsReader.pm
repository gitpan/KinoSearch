use KinoSearch;

1;

__END__

__BINDING__

my $synopsis = <<'END_SYNOPSIS';
    my $postings_reader 
        = $seg_reader->obtain("KinoSearch::Index::PostingsReader");
    my $posting_list = $postings_reader->posting_list(
        field => 'title', 
        term  => 'foo',
    );
END_SYNOPSIS

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::PostingsReader",
    bind_constructors => ["new"],
    bind_methods      => [qw( Posting_List Get_Lex_Reader )],
    make_pod          => {
        synopsis => $synopsis,
        methods  => [qw( posting_list )],
    },
);
Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Index::DefaultPostingsReader",
    bind_constructors => ["new"],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
