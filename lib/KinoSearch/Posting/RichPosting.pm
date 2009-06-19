use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    # RichPosting is used indirectly, by specifying in FieldType subclass.
    package MySchema::Category;
    use base qw( KinoSearch::FieldType::FullTextType );
    sub posting {
        my $self = shift;
        return KinoSearch::Posting::RichPosting->new(@_);
    }
END_SYNOPSIS

{   "KinoSearch::Posting::RichPosting" => {
        make_constructors  => ["new"],
#        make_pod => {
#            synopsis => $synopsis,
#        }
    }
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

