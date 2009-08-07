use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Store::Folder" => {
        bind_methods => [
            qw( Open_Out
                Open_In
                MkDir
                List
                Exists
                Rename
                Hard_Link
                Delete 
                Finish_Segment
                Slurp_File
                Close
                )
        ],
        make_constructors => ["new"],
        make_getters => [qw( path )],
        make_pod => {
            synopsis => "    # Abstract base class.\n",
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

