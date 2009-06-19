use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch  PACKAGE = KinoSearch::Store::Lock

void
set_commit_lock_timeout(value);
    chy_u32_t value;
PPCODE:
    kino_Lock_commit_lock_timeout = value;

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $lock = $lock_factory->make_lock(
        lock_name => 'commit',
        timeout   => 5000,
    );
    $lock->obtain or die "can't get lock on " . $lock->get_filename;
    do_stuff();
    $lock->release;
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $lock = KinoSearch::Store::Lock->new(
        lock_name => 'commit',           # required
        timeout   => 5000,               # default: 0
        folder    => $folder,            # required
        agent_id  => $hostname,          # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Store::Lock" => {
        bind_methods =>
            [qw( Obtain Do_Obtain Is_Locked Release Clear_Stale )],
        make_getters => [qw( folder timeout lock_name agent_id filename )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [qw( obtain release is_locked clear_stale )]
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

