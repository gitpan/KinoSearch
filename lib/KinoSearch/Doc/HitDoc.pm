use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    while ( my $hit_doc = $hits->next ) {
        print "$hit_doc->{title}\n";
        print $hit_doc->get_score . "\n";
        ...
    }
END_SYNOPSIS

{   "KinoSearch::Doc::HitDoc" => {
        make_constructors => ['new'],
        bind_methods      => [qw( Set_Score Get_Score )],
        make_pod          => {
            methods  => [qw( set_score get_score )],
            synopsis => $synopsis,
        },
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
