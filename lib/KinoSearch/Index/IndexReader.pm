use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Index::IndexReader

void
set_race_condition_debug1(val_sv)
    SV *val_sv;
PPCODE:
    KINO_DECREF(kino_PolyReader_race_condition_debug1);
    kino_PolyReader_race_condition_debug1 =
        (kino_CharBuf*)MAYBE_SV_TO_KOBJ(val_sv, &KINO_CHARBUF);
    if (kino_PolyReader_race_condition_debug1)
        (void)KINO_INCREF(kino_PolyReader_race_condition_debug1);

chy_i32_t
debug1_num_passes()
CODE: 
    RETVAL = kino_PolyReader_debug1_num_passes;
OUTPUT: RETVAL

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $reader = KinoSearch::Index::IndexReader->open(
        index => '/path/to/index',
    );
    my $seg_readers = $reader->seg_readers;
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

my $constructor = <<'END_CONSTRUCTOR';
    my $reader = KinoSearch::Index::IndexReader->open(
        index        => '/path/to/index', # required
        snapshot     => $snapshot,
        lock_factory => $lock_factory,
    );
END_CONSTRUCTOR

{   "KinoSearch::Index::IndexReader" => {
        bind_methods => [
            qw( Doc_Max
                Doc_Count 
                Del_Count
                Fetch
                Obtain
                Seg_Readers
                _offsets|Offsets
                Get_Lock_Factory
                Get_Components
                )
        ],
        make_constructors => ['open|do_open'],
        make_pod => {
            synopsis => $synopsis,
            constructor => {
                name   => 'open',
                func   => 'do_open',
                sample => $constructor,
            },
            methods => [qw(
                doc_max
                doc_count 
                del_count
                seg_readers
                offsets
                fetch
                obtain
            )]
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

