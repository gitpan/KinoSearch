use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        language => 'en',
    );
    my $type = KinoSearch::FieldType::FullTextType->new(
        analyzer => $polyanalyzer,
    );
    my $schema = KinoSearch::Schema->new;
    $schema->spec_field( name => 'title',   type => $type );
    $schema->spec_field( name => 'content', type => $type );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $type = KinoSearch::FieldType::FullTextType->new(
        analyzer      => $analyzer,    # required
        boost         => 2.0,          # default: 1.0
        indexed       => 1,            # default: true
        stored        => 1,            # default: true
        highlightable => 1,            # default: false
    );
END_CONSTRUCTOR

{   "KinoSearch::FieldType::FullTextType" => {
        make_constructors => ["new|init2"],
        bind_methods      => [
            qw(
                Set_Highlightable
                Highlightable 
                )
        ],
        make_pod => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [
                qw(
                    set_highlightable
                    highlightable 
                    )
            ],
        },
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

