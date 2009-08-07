use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $polyreader  = $del_writer->get_polyreader;
    my $seg_readers = $polyreader->seg_readers;
    for my $seg_reader (@$seg_readers) {
        my $count = $del_writer->seg_del_count( $seg_reader->get_seg_name );
        ...
    }
END_SYNOPSIS

{   "KinoSearch::Index::DeletionsWriter" => {
        bind_methods => [
            qw(
                Generate_Doc_Map
                Delete_By_Term
                Delete_By_Query
                Delete_By_Doc_ID
                Updated
                Seg_Deletions
                Seg_Del_Count
                )
        ],
        make_pod => {
            synopsis => $synopsis,
            methods => [
            qw(
                Delete_By_Term
                Delete_By_Query
                Updated
                Seg_Del_Count
                )
        ],
        },
    },
    "KinoSearch::Index::DefaultDeletionsWriter" =>
        { make_constructors => ["new"], },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.