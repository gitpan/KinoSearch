use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    use Sys::Hostname qw( hostname );
    my $hostname = hostname() or die "Can't get unique hostname";
    my $manager = KinoSearch::Index::IndexManager->new( 
        hostname => $hostname,
    );

    # Index time:
    my $indexer = KinoSearch::Indexer->new(
        index   => '/path/to/index',
        manager => $manager,
    );

    # Search time:
    my $reader = KinoSearch::Index::IndexReader->open(
        index   => '/path/to/index',
        manager => $manager,
    );
    my $searcher = KinoSearch::Searcher->new( index => $reader );
END_SYNOPSIS

{   "KinoSearch::Docs::FileLocking" => {
        make_pod => { synopsis => $synopsis, },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

