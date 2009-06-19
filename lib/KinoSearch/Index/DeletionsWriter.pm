use KinoSearch;

1;

__END__

__AUTO_XS__

{   "KinoSearch::Index::DeletionsWriter" => {
        bind_methods => [
            qw(
                Generate_Doc_Map
                Delete_By_Term
                Updated
                Seg_Deletions
                )
        ],
    },
    "KinoSearch::Index::DefaultDeletionsWriter" => { 
        make_constructors => ["new"], 
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
