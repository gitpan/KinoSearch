use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Search::SortRule

chy_i32_t
FIELD()
CODE:
    RETVAL = kino_SortRule_FIELD;
OUTPUT: RETVAL

chy_i32_t
SCORE()
CODE:
    RETVAL = kino_SortRule_SCORE;
OUTPUT: RETVAL

chy_i32_t
DOC_ID()
CODE:
    RETVAL = kino_SortRule_DOC_ID;
OUTPUT: RETVAL

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $sort_spec = KinoSearch::Search::SortSpec->new(
        rules => [
            KinoSearch::Search::SortRule->new( field => 'date' ),
            KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
        ],
    );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $by_title   = KinoSearch::Search::SortRule->new( field => 'title' );
    my $by_score   = KinoSearch::Search::SortRule->new( type  => 'score' );
    my $by_doc_id  = KinoSearch::Search::SortRule->new( type  => 'doc_id' );
    my $reverse_date = KinoSearch::Search::SortRule->new(
        field   => 'date',
        reverse => 1,
    );
END_CONSTRUCTOR

{   "KinoSearch::Search::SortRule" => {
        make_constructors => ["_new"],
        bind_methods      => [qw( Get_Field Get_Reverse )],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [qw( get_field get_reverse )],
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

