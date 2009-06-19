use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Analysis::Stemmer

void
_copy_snowball_symbols()
PPCODE:
{
    SV *sb_stemmer_new_sv = XSBind_extract_sv(PL_modglobal,
        "Lingua::Stem::Snowball::sb_stemmer_new", 38);
    SV *sb_stemmer_delete_sv = XSBind_extract_sv(PL_modglobal,
        "Lingua::Stem::Snowball::sb_stemmer_delete", 41);
    SV *sb_stemmer_stem_sv = XSBind_extract_sv(PL_modglobal,
        "Lingua::Stem::Snowball::sb_stemmer_stem", 39);
    SV *sb_stemmer_length_sv = XSBind_extract_sv(PL_modglobal,
        "Lingua::Stem::Snowball::sb_stemmer_length", 41);
    kino_Stemmer_sb_stemmer_new 
        = (kino_Stemmer_sb_stemmer_new_t)SvIV(sb_stemmer_new_sv);
    kino_Stemmer_sb_stemmer_delete 
        = (kino_Stemmer_sb_stemmer_delete_t)SvIV(sb_stemmer_delete_sv);
    kino_Stemmer_sb_stemmer_stem 
        = (kino_Stemmer_sb_stemmer_stem_t)SvIV(sb_stemmer_stem_sv);
    kino_Stemmer_sb_stemmer_length 
        = (kino_Stemmer_sb_stemmer_length_t)SvIV(sb_stemmer_length_sv);
}

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $stemmer = KinoSearch::Analysis::Stemmer->new( language => 'es' );
    
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $case_folder, $tokenizer, $stemmer ],
    );

This class is a wrapper around L<Lingua::Stem::Snowball>, so it supports the
same languages.  
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $stemmer = KinoSearch::Analysis::Stemmer->new( language => 'es' );
END_CONSTRUCTOR

{   "KinoSearch::Analysis::Stemmer" => {
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor }
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself

