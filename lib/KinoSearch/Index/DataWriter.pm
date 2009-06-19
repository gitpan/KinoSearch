use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<END_SYNOPSIS;
    # Abstract base class.
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $writer = MyDataWriter->new(
        snapshot   => $snapshot,      # required
        segment    => $segment,       # required
        polyreader => $polyreader,    # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Index::DataWriter" => {
        bind_methods => [
            qw(
                Add_Inverted_Doc
                Add_Segment
                Delete_Segment
                Merge_Segment
                Finish
                Format
                Metadata
                Get_Snapshot
                Get_Segment
                Get_PolyReader
                Get_Schema
                Get_Folder
                )
        ],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [
                qw(
                    add_inverted_doc
                    add_segment
                    delete_segment
                    merge_segment
                    finish
                    format
                    metadata
                    get_snapshot
                    get_segment
                    get_polyreader
                    get_schema
                    get_folder
                    )
            ],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
