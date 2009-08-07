use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    while (1) {
        my $bg_merger = eval {
            KinoSearch::Index::BackgroundMerger->new( index => $index );
        };
        if ( blessed($@) and $@->isa("KinoSearch::Store::LockErr") ) {
            warn "Retrying...\n";
        }
        elsif (!$bg_merger) {
            # Re-throw.
            die "Failed to open BackgroundMerger: $@";
        }
        ...
    }
END_SYNOPSIS

{   
    "KinoSearch::Store::LockErr" => { 
        make_pod => { synopsis => $synopsis }
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

