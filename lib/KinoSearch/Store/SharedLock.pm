use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $folder,
        agent_id  => $hostname,
    );
    my $shlock = $lock_factory->make_shared_lock(
        lock_name => 'snapshot_6r',
        timeout   => 5000,
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $shlock = KinoSearch::Store::SharedLock->new(
        lock_name => 'commit',           # required
        timeout   => 5000,               # default: 0
        folder    => $folder,            # required
        agent_id  => $hostname,          # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::SharedLock" => {
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

