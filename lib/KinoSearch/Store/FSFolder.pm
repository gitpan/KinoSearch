use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $folder = KinoSearch::Store::FSFolder->new(
        path   => '/path/to/folder',
    );
END_SYNOPSIS

my $constructor = $synopsis;

{   "KinoSearch::Store::FSFolder" => {
        bind_methods      => [qw( Real_Exists )],
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

