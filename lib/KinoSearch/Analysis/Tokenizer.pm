use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $whitespace_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( pattern => '\S+' );

    # or...
    my $word_char_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( pattern => '\w+' );

    # or...
    my $apostrophising_tokenizer = KinoSearch::Analysis::Tokenizer->new;

    # Then... once you have a tokenizer, put it into a PolyAnalyzer:
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $case_folder, $word_char_tokenizer, $stemmer ], );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $word_char_tokenizer = KinoSearch::Analysis::Tokenizer->new(
        pattern => '\w+',    # required
    );
END_CONSTRUCTOR

{   "KinoSearch::Analysis::Tokenizer" => {
        bind_methods      => [qw( Set_Token_RE )],
        make_constructors => ["_new"],
        make_pod          => {
            constructor => { sample => $constructor },
            synopsis    => $synopsis,
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

