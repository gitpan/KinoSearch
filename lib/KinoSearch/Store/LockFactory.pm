use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    use Sys::Hostname qw( hostname );
    my $hostname = hostname() or die "Can't get unique hostname";
    my $folder = KinoSearch::Store::FSFolder->new( 
        path => '/path/to/index', 
    );
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder   => $folder,
        hostname => $hostname,
    );
    my $write_lock = $lock_factory->make_lock(
        name     => 'write',
        timeout  => 5000,
        interval => 100,
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder   => $folder,    # required
        hostname => $hostname,  # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::LockFactory" => {
        bind_methods      => [qw( Make_Lock Make_Shared_Lock )],
        make_getters      => [qw( folder hostname )],
        make_constructors => ["new"],
        make_pod          => {
            methods => [ qw( make_lock make_shared_lock) ],
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        }
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

