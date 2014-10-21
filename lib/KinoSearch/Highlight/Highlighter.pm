package KinoSearch::Highlight::Highlighter;
use KinoSearch;

1;

__END__

__BINDING__

my $synopsis = <<'END_SYNOPSIS';
    my $highlighter = KinoSearch::Highlight::Highlighter->new(
        searcher => $searcher,
        query    => $query,
        field    => 'body'
    );
    my $hits = $searcher->hits( query => $query );
    while ( my $hit = $hits->next ) {
        my $excerpt = $highlighter->create_excerpt($hit);
        ...
    }
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $highlighter = KinoSearch::Highlight::Highlighter->new(
        searcher       => $searcher,    # required
        query          => $query,       # required
        field          => 'content',    # required
        excerpt_length => 150,          # default: 200
    );
END_CONSTRUCTOR

Clownfish::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Highlight::Highlighter",
    bind_methods => [
        qw(
            Highlight
            Encode
            Create_Excerpt
            _find_best_fragment|Find_Best_Fragment
            _raw_excerpt|Raw_Excerpt
            _highlight_excerpt|Highlight_Excerpt
            Find_Sentences
            Set_Pre_Tag
            Get_Pre_Tag
            Set_Post_Tag
            Get_Post_Tag
            Get_Searcher
            Get_Query
            Get_Compiler
            Get_Excerpt_Length
            Get_Field
            )
    ],
    bind_constructors => ["new"],
    make_pod          => {
        synopsis    => $synopsis,
        constructor => { sample => $constructor },
        methods     => [
            qw(
                create_excerpt
                highlight
                encode
                set_pre_tag
                get_pre_tag
                set_post_tag
                get_post_tag
                get_searcher
                get_query
                get_compiler
                get_excerpt_length
                get_field
                )
        ]
    },
);

__COPYRIGHT__

Copyright 2005-2010 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

