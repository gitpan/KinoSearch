use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $folder = KinoSearch::Store::RAMFolder->new;
    
    # or sometimes...
    my $folder = KinoSearch::Store::RAMFolder->new(
        path   => '/path/to/folder',
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $folder = KinoSearch::Store::RAMFolder->new(
        path   => '/path/to/folder',   # optional
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::RAMFolder" => {
        bind_methods      => [qw( RAM_File )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        }
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

