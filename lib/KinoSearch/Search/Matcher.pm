use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    # Matcher is an abstract base class -- see MockScorer for an example
    # implementation.
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR_CODE_SAMPLE';
    my $matcher = MyMatcher->SUPER::new;
END_CONSTRUCTOR_CODE_SAMPLE

{   "KinoSearch::Search::Matcher" => {
        bind_methods      => [qw( Next Advance Get_Doc_ID Score Collect )],
        make_constructors => ["new"],
        make_pod => {
            synopsis => $synopsis,
            constructor => { sample => $constructor },
            methods => [qw( next advance get_doc_id score )],
        }
    }
}

__COPYRIGHT__

Copyright 2008-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.


