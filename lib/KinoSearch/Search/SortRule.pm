package KinoSearch::Search::SortRule;
use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Search::SortRule

int32_t
FIELD()
CODE:
    RETVAL = kino_SortRule_FIELD;
OUTPUT: RETVAL

int32_t
SCORE()
CODE:
    RETVAL = kino_SortRule_SCORE;
OUTPUT: RETVAL

int32_t
DOC_ID()
CODE:
    RETVAL = kino_SortRule_DOC_ID;
OUTPUT: RETVAL
END_XS_CODE

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

Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Search::SortRule",
    xs_code           => $xs_code,
    bind_constructors => ["_new"],
    bind_methods      => [qw( Get_Field Get_Reverse )],
    make_pod          => {
        synopsis    => $synopsis,
        constructor => { sample => $constructor },
        methods     => [qw( get_field get_reverse )],
    },
);

__COPYRIGHT__

Copyright 2005-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

