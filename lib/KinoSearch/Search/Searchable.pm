use KinoSearch;

1;

__END__

__AUTO_XS__

my $constructor = <<'END_CONSTRUCTOR';
    package MySearchable;
    use base qw( KinoSearch::Search::Searchable );
    sub new {
        my $self = shift->SUPER::new;
        ...
        return $self;
    }
END_CONSTRUCTOR

{   "KinoSearch::Search::Searchable" => {
        bind_methods => [
            qw( Doc_Max
                Doc_Freq
                Glean_Query
                Hits 
                Collect
                Top_Docs
                Fetch_Doc
                Fetch_Doc_Vec 
                Get_Schema
                Close )
        ],
        make_constructors => ["new"],
        make_pod => {
            synopsis => "    # Abstract base class.\n",
            constructor => { sample => $constructor },
            methods => [qw(
                hits 
                collect
                glean_query
                doc_max
                doc_freq
                fetch_doc
                get_schema
            )],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

