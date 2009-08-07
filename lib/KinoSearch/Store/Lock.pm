use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $lock = $lock_factory->make_lock(
        name    => 'write',
        timeout => 5000,
    );
    $lock->obtain or die "can't get lock for " . $lock->get_name;
    do_stuff();
    $lock->release;
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $lock = KinoSearch::Store::Lock->new(
        name     => 'commit',     # required
        folder   => $folder,      # required
        hostname => $hostname,    # required
        timeout  => 5000,         # default: 0
        interval => 1000,         # default: 100
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::Lock" => {
        bind_methods => [
            qw(
                Obtain
                Request
                Is_Locked
                Release
                Clear_Stale
                )
        ],
        make_getters => [qw( folder timeout name hostname filename )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [
                qw(
                    obtain
                    request
                    release
                    is_locked
                    clear_stale
                    )
            ],
        },
    },
    "KinoSearch::Store::LockFileLock" => {
        make_constructors => ["new"],
    },
    "KinoSearch::Store::SharedLock" => {
        make_constructors => ["new"],
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

