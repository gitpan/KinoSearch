use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopis = <<'END_SYNOPSIS';
    # abstract base class
END_SYNOPSIS

{   "KinoSearch::FieldType" => {
        bind_methods => [
            qw(
                Set_Boost
                Get_Boost
                Set_Indexed
                Indexed
                Set_Stored
                Stored
                Binary
                Compare_Values
                )
        ],
        make_constructors => ["new|init2"],
        make_pod => {
            synopsis => $synopis,
            methods  => [
                qw(
                    set_boost
                    get_boost
                    set_indexed
                    indexed
                    set_stored
                    stored
                    binary
                    )
            ],
        }
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

