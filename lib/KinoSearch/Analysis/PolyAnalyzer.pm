use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $schema = KinoSearch::Schema->new;
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new( 
        language => 'en',
    );
    my $type = KinoSearch::FieldType::FullTextType->new(
        analyzer => $polyanalyzer,
    );
    $schema->spec_field( name => 'title',   type => $type );
    $schema->spec_field( name => 'content', type => $type );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        language  => 'es',
    );
    
    # or...

    my $case_folder  = KinoSearch::Analysis::CaseFolder->new;
    my $tokenizer    = KinoSearch::Analysis::Tokenizer->new;
    my $stemmer      = KinoSearch::Analysis::Stemmer->new( language => 'en' );
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $case_folder, $whitespace_tokenizer, $stemmer, ], );
END_CONSTRUCTOR

{   "KinoSearch::Analysis::PolyAnalyzer" => {
        make_constructors => ["new"],
        make_pod          => {
            methods     => [qw( get_analyzers )],
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
