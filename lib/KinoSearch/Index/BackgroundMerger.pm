use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $bg_merger = KinoSearch::Index::BackgroundMerger->new(
        index  => '/path/to/index',
    );
    $bg_merger->commit;
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $bg_merger = KinoSearch::Index::BackgroundMerger->new(
        index   => '/path/to/index',    # required
        manager => $manager             # default: created internally
    );
END_CONSTRUCTOR

{   "KinoSearch::Index::BackgroundMerger" => {
        bind_methods => [
            qw(
                Commit
                Prepare_Commit
                Optimize
                )
        ],
        make_constructors => ["new"],
        make_pod          => {
            methods => [
                qw(
                    commit
                    prepare_commit
                    optimize
                    )
            ],
            synopsis     => $synopsis,
            constructors => [ { sample => $constructor } ],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

