use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $polyreader = KinoSearch::Index::IndexReader->open(
        index => '/path/to/index',
    );
    my $seg_readers = $polyreader->seg_readers;
    for my $seg_reader (@$seg_readers) {
        my $seg_name = $seg_reader->get_segment->get_name;
        my $num_docs = $seg_reader->doc_max;
        print "Segment $seg_name ($num_docs documents):\n";
        my $doc_reader = $seg_reader->obtain("KinoSearch::Index::DocReader");
        for my $doc_id ( 1 .. $num_docs ) {
            my $doc = $doc_reader->fetch($doc_id);
            print "  $doc_id: $doc->{title}\n";
        }
    }
END_SYNOPSIS

{   "KinoSearch::Index::SegReader" => {
        bind_methods      => [qw( Register )],
        make_constructors => ["new"],
        make_pod          => { synopsis => $synopsis },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

