use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    use Sys::Hostname;
    my $hostname = hostname();
    die "Can't get unique hostname" unless $hostname;

    my $folder = KinoSearch::Store::FSFolder->new(
        path => '/path/to/index/on/nfs/volume',
    );
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $folder,
        agent_id  => $hostname,
    );
    my $index_reader = KinoSearch::Index::IndexReader->open(
        folder       => $folder,
        lock_factory => $lock_factory,
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $lock_factory = KinoSearch::Store::LockFactory->new(
        folder    => $folder,    # required
        agent_id  => $hostname,  # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::LockFactory" => {
        bind_methods      => [qw( Make_Lock Make_Shared_Lock )],
        make_getters      => [qw( folder agent_id )],
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

