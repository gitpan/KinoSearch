use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    # MatchPosting is used indirectly, by specifying in FieldType subclass.
    package MySchema::Category;
    use base qw( KinoSearch::FieldType::FullTextType );
    sub posting {
        my $self = shift;
        return KinoSearch::Posting::MatchPosting->new(@_);
    }
END_SYNOPSIS

{   "KinoSearch::Posting::MatchPosting" => {
        make_constructors  => ["new"],
        make_getters       => [qw( freq )],
#        make_pod => {
#            synopsis => $synopsis,
#        }
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

